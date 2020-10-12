/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// Bindings to some chrome.runtime APIs.
@JS('chrome.runtime')
library stratos.chrome.runtime;

import 'dart:async';

import 'package:js/js.dart';

import 'event.dart';

@JS()
@anonymous
class LastError {
  external String get message;
}

@JS()
external LastError get lastError;

@JS()
external String getURL(String url);

@JS()
@anonymous
class _JsPort {
  external String get name;
  external Event get onMessage;
  external Event get onDisconnect;

  external void postMessage(dynamic message);
  external void disconnect();
}

class Port {
  final _JsPort _js;
  Port._(this._js) {
    _onMessageCallback = allowInterop((dynamic message, dynamic _) {
      _onMessageController.add(message);
    });

    _onMessageController =
        createEventStreamController<dynamic>(_js.onMessage, _onMessageCallback);

    _outgoingController = StreamController<dynamic>();
    _outgoingController.stream
        .listen((dynamic message) => _js.postMessage(message));

    _js.onDisconnect
        .addListener(allowInterop((dynamic _) => _finishDisconnect()));
  }

  String get name => _js.name;

  void close() {
    _js.disconnect();
    _finishDisconnect();
  }

  void _finishDisconnect() {
    _onMessageController.close();
    _outgoingController.close();
    _disconnectCompleter.complete();
  }

  Function _onMessageCallback;
  StreamController<dynamic> _onMessageController;

  StreamController<dynamic> _outgoingController;

  final _disconnectCompleter = Completer<void>();

  Stream<dynamic> get onMessage => _onMessageController.stream;
  StreamSink<dynamic> get outgoing => _outgoingController.sink;

  Future<void> get onDisconnect => _disconnectCompleter.future;
}

@JS()
@anonymous
class _ConnectInfo {
  external String get name;
  external bool get includeTlsChannelId;

  external factory _ConnectInfo({String name, bool includeTlsChannelId});
}

@JS('connect')
external _JsPort _connect(String extensionId, _ConnectInfo connectInfo);

Port connect({String extensionId, String name, bool includeTlsChannelId}) =>
    Port._(_connect(extensionId,
        _ConnectInfo(name: name, includeTlsChannelId: includeTlsChannelId)));

@JS('onConnect')
external Event get _onConnect;

final _onConnectController =
    createEventStreamController<Port>(_onConnect, _onConnectCallback);

final Function _onConnectCallback = allowInterop((_JsPort jsPort) {
  _onConnectController.add(Port._(jsPort));
});

Stream<Port> get onConnect => _onConnectController.stream;
