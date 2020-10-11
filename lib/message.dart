/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// This contains the messaging system that the injected script and popup use
/// to talk to the background page & sync engine. The background page is always
/// the "host", and everyone communicating with it is a "client".
library stratos.message;

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratos/capture.dart';
import 'package:stratos/chrome/runtime.dart' as chrome_runtime;

part 'message.freezed.dart';
part 'message.g.dart';

/// The ends of a message pipe.
enum MessageSide { client, host }

const messagePort = 'stratos-messages';
const clientToHostMessagePrefix = 'stratus-message-client-to-host:';
const hostToClientMessagePrefix = 'stratus-message-host-to-client:';

abstract class MessageToJson {
  dynamic toJson();
}

/// The sync status of a capture.
@freezed
abstract class SyncStatus with _$SyncStatus {
  /// The capture is not synced.
  factory SyncStatus.unsynced() = Unsynced;

  /// The capture is queued to be synced or currently being uploaded. If it is
  /// being uploaded, progress will be a value in the range `[0,1]` representing
  /// the current percentage complete, otherwise it will be `null`.
  factory SyncStatus.inProgress([double progress]) = InProgress;

  /// The capture is uploaded safely.
  factory SyncStatus.complete() = Complete;

  factory SyncStatus.fromJson(Map<String, dynamic> json) =>
      _$SyncStatusFromJson(json);
}

/// A pairing of a capture with its sync status.
@JsonSerializable()
class CaptureSyncStatus {
  final Capture capture;
  SyncStatus status;

  CaptureSyncStatus(this.capture, this.status);

  factory CaptureSyncStatus.fromJson(Map<String, dynamic> data) =>
      _$CaptureSyncStatusFromJson(data);
  Map<String, dynamic> toJson() => _$CaptureSyncStatusToJson(this);
}

/// A message intended for a host and written by a client.
@freezed
abstract class ClientToHostMessage
    with _$ClientToHostMessage
    implements MessageToJson {
  /// Asks the host to re-authenticate.
  factory ClientToHostMessage.requestAuth() = RequestAuth;

  /// Notifies the background page of a set of captures. If [fromScratch] is
  /// `true`, then this is the first set of captures sent from a new page,
  /// otherwise, it is a set of *more* captures, to be added to the first set.
  factory ClientToHostMessage.latestCaptures(CaptureSet captures,
      {@Default(false) bool fromScratch}) = LatestCaptures;

  /// Requests that the given capture (by ID) should be synced.
  factory ClientToHostMessage.requestSync(String id) = RequestSync;

  /// Requests that all known captures should be synced.
  factory ClientToHostMessage.requestSyncAll() = RequestSyncAll;

  factory ClientToHostMessage.fromJson(Map<String, dynamic> json) =>
      _$ClientToHostMessageFromJson(json);
}

/// A message intended for a client and written by the host.
@freezed
abstract class HostToClientMessage
    with _$HostToClientMessage
    implements MessageToJson {
  /// Notifies the client whether or not sync is currently enabled.
  factory HostToClientMessage.syncAvailability(bool enabled) = EnableSync;

  /// Notifies the client of the latest capture sync statuses, potentially only
  /// including the statuses that changed (i.e. this may not contain the status
  /// for the entire known capture set). This is emitted whenever the status
  /// changes, or when a new set of captures is sent to the host which then
  /// determines the sync status of each one. It is also sent for all known
  /// captures when a new client connects.
  factory HostToClientMessage.updateCaptureStatuses(
      Map<String, CaptureSyncStatus> idToSyncStatus) = UpdateCaptureStatuses;

  factory HostToClientMessage.fromJson(Map<String, dynamic> json) =>
      _$HostToClientMessageFromJson(json);
}

/// A communication delegate used by a message pipe.
abstract class MessagePipeDelegate {
  /// A broadcast stream emitted on new messages.
  Stream<String> get onMessage;

  /// A future completed when the pipe is disconnected. This may be null, in
  /// which case this delegate has no concept of being disconnected.
  Future<void> get onDisconnect;

  /// Sends a new message over the delegate.
  void post(String message);

  /// Closes the delegate.
  void close();
}

/// A [MessagePipeDelegate] that talks over the Chrome extension ports API.
class PortMessagePipeDelegate implements MessagePipeDelegate {
  final chrome_runtime.Port port;
  PortMessagePipeDelegate(this.port) {
    port.onDisconnect.then(_disconnectCompleter.complete);
  }

  factory PortMessagePipeDelegate.connect() =>
      PortMessagePipeDelegate(chrome_runtime.connect(name: messagePort));

  final _disconnectCompleter = Completer<void>();

  @override
  Stream<String> get onMessage => port.onMessage.cast<String>();

  @override
  Future<void> get onDisconnect => _disconnectCompleter.future;

  @override
  void post(String message) => port.outgoing.add(message);

  @override
  void close() => port.close();
}

/// A [MessagePipeDelegate] that communities via the browser window messaging
/// API. In particular, this is used by the injected script to talk to the
/// content script, which then forwards the messages to the background page.
///
/// Since both messages coming in and out are sent over the window, a prefix is
/// used to differentiate between who it is intended for. This is why the side
/// must be passed to the constructor.
class WindowMessagePipeDelegate implements MessagePipeDelegate {
  /// The side of a message pipe that this represents.
  final MessageSide side;

  WindowMessagePipeDelegate({@required this.side});

  String get _incomingPrefix => side == MessageSide.client
      ? hostToClientMessagePrefix
      : clientToHostMessagePrefix;
  String get _outgoingPrefix => side == MessageSide.client
      ? clientToHostMessagePrefix
      : hostToClientMessagePrefix;

  @override
  Future<void> get onDisconnect => null;

  @override
  Stream<String> get onMessage => window.onMessage
      .where((event) => event.data is String)
      .map((event) => event.data as String)
      .where((message) => message.startsWith(_incomingPrefix))
      .map((message) => message.substring(_incomingPrefix.length));

  @override
  void post(String message) =>
      window.postMessage(_outgoingPrefix + message, '*');

  @override
  void close() {}
}

/// A "pipe" that can be used to send messages to a host or client.
class MessagePipe<Outgoing extends MessageToJson,
    Incoming extends MessageToJson> {
  /// A factory function that takes in a JSON-formatted incoming message and
  /// creates a message instance from it.
  final Incoming Function(Map<String, dynamic> data) incomingFactory;
  final MessagePipeDelegate delegate;

  final _incomingController = StreamController<Incoming>();
  final _outgoingController = StreamController<Outgoing>();

  MessagePipe({@required this.incomingFactory, @required this.delegate}) {
    _outgoingController.stream
        .listen((message) => delegate.post(json.encode(message.toJson())));

    var onDisconnect = delegate.onDisconnect;
    if (onDisconnect != null) {
      onDisconnect.then((void _) {
        _incomingController.close();
        _outgoingController.close();
      });
    }

    // delegate.onMessage may be a broadcast stream, which makes *sense*...but,
    // if the other end proceeds to immediately send any new messages on
    // connection, they may be lost unless we quickly start taking them in and
    // forwarding them to a single-subscription stream where they'll be held.
    delegate.onMessage
        .map((message) =>
            incomingFactory(json.decode(message) as Map<String, dynamic>))
        .pipe(_incomingController.sink);
  }

  /// A *single-subscription* stream of the incoming messages.
  Stream<Incoming> get onMessage => _incomingController.stream;
  StreamSink<Outgoing> get outgoing => _outgoingController.sink;

  void close() => delegate.close();
}

/// A bridge that forwards the messages incoming on one message pipe to those
/// outgoing on another. This is a bidirectional bridge, so both side's incoming
/// will be forwarded to the other's outgoing.
class MessagePipeBridge {
  final MessagePipeDelegate first, second;
  MessagePipeBridge(this.first, this.second);

  /// FOrward all messages bidirectionally between the delegates.
  Future<void> forwardAll() => Future.wait<void>([
        first.onMessage.forEach(second.post),
        second.onMessage.forEach(first.post)
      ]);
}

/// A [MessagePipe] intended to be used on a client side.
class ClientSideMessagePipe
    extends MessagePipe<ClientToHostMessage, HostToClientMessage> {
  ClientSideMessagePipe(MessagePipeDelegate delegate)
      : super(
            incomingFactory: (data) => HostToClientMessage.fromJson(data),
            delegate: delegate);
}

/// A [MessagePipe] intended to be used on a host side.
class HostSideMessagePipe
    extends MessagePipe<HostToClientMessage, ClientToHostMessage> {
  HostSideMessagePipe(MessagePipeDelegate delegate)
      : super(
            incomingFactory: (data) => ClientToHostMessage.fromJson(data),
            delegate: delegate);
}
