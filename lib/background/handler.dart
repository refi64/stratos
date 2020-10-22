/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:async';

import 'package:stratos/background/auth.dart';
import 'package:stratos/background/sync.dart';
import 'package:stratos/capture.dart';
import 'package:stratos/log.dart';
import 'package:stratos/message.dart';

/// A handler for client-to-host messages.
class MessageHandler {
  final _outgoingController = StreamController<HostToClientMessage>.broadcast();

  /// Returns a stream that contains outgoing messages from this handler. The
  /// user of the handler should forward these back to the client.
  Stream<HostToClientMessage> get outgoing => _outgoingController.stream;

  final AuthService _authService;
  final SyncService _sync;
  // NOTE: Really, this should one map of String: CaptureSyncStatus, instead of
  // separate captures & statuses, but at the first time this code was written,
  // CaptureSyncStatus didn't exist, and...to be frank, I don't feel like
  // changing the code...
  var _captures = CaptureSet();
  // A cache of the sync statuses for all known captures, to avoid rechecking
  // every time.
  final _statuses = <String, SyncStatus>{};

  MessageHandler(AuthService authService)
      : _authService = authService,
        _sync = SyncService(authService) {
    _sync.onProgress.listen((result) {
      logger.d('Sync progress for ${result.capture.id}: ${result.status}');
      if (_statuses.containsKey(result.capture.id)) {
        _updateStatuses({result.capture.id: result.status});
      }
    });
  }

  /// Sends all the current statuses to all clients.
  void sendCurrentStatuses() {
    _sendUpdatedStatuses(_statuses);
  }

  /// Send the given status updates to all clients.
  void _sendUpdatedStatuses(Map<String, SyncStatus> updates) {
    logger.d('Sending statuses for: ${updates.keys.join(' ')}');
    var toSend = <String, CaptureSyncStatus>{};
    for (var update in updates.entries) {
      var capture = _captures.capturesById[update.key];
      if (capture == null) {
        logger.e('Tried to send status for missing capture ${update.key}');
        continue;
      }

      toSend[update.key] = CaptureSyncStatus(capture, update.value);
    }

    _outgoingController.add(HostToClientMessage.updateCaptureStatuses(toSend));
  }

  /// Updates the local statuses with the given updates, and sends them all to
  /// all clients.
  void _updateStatuses(Map<String, SyncStatus> updates) {
    _statuses.addAll(updates);
    _sendUpdatedStatuses(updates);
  }

  Future<void> _handleRequestAuth() async {
    await _authService.runInteractiveAuthRequest();
  }

  Future<void> _handleLatestCaptures(
      CaptureSet newCaptures, bool fromScratch) async {
    // XXX: Should this clear out the cached sync statuses? Right now, they're
    // never cleared, so deleted captures leak memory...but unless someone
    // deletes an insane amount without ever restarting Chrome, it shouldn't
    // actually be a major issue. I hope.
    if (fromScratch) {
      _captures = newCaptures;
    } else {
      _captures.capturesById.addAll(newCaptures.capturesById);
    }

    // We have to check every capture and compare it to the latest in the Drive
    // account. If all the captures are checked, then the messages sent, it may
    // take a long time for the user to be able to begin uploading. *However*,
    // if each is sent out once checked, any cached ones will be sent out each
    // time as well, even though they could be sent in one go since finding them
    // is a quick lookup. Therefore, we use a hybrid approach: save up all the
    // cached statuses, but once we hit one that's not cached, send it
    // immediately, along with any other cached ones.
    var currentChanges = <String, SyncStatus>{};
    for (var id in newCaptures.capturesById.keys) {
      logger.d('Checking capture id: $id');

      if (_statuses[id] != null) {
        currentChanges[id] = _statuses[id];
      } else {
        try {
          var url = await _sync.getAlreadySyncedLink(id);
          currentChanges[id] =
              url != null ? SyncStatus.complete(url) : SyncStatus.unsynced();
        } on MissingAuthException {
          logger.i('Lost auth access, so stopping change checks');
          break;
        } catch (ex) {
          logger.e('Checking capture sync status: $ex');
          currentChanges[id] = SyncStatus.unsynced();
        }

        _updateStatuses(currentChanges);
        currentChanges.clear();
      }
    }

    // Send out any remaining cached ones.
    if (currentChanges.isNotEmpty) {
      _updateStatuses(currentChanges);
    }
  }

  Future<void> _handleRequestSync(String id) async {
    logger.d('Request sync: $id');
    var capture = _captures.capturesById[id];
    if (capture == null) {
      logger.i('Unknown id: $id');
    } else if (_statuses[id] is Unsynced) {
      _sync.requests.add(capture);
      _statuses[id] = SyncStatus.inProgress();
    }

    _updateStatuses({id: _statuses[id]});
  }

  Future<void> _handleRequestSyncAll() async {
    logger.d('Request sync all');
    var changes = <String, SyncStatus>{};

    for (var capture in _captures.capturesById.values) {
      if (_statuses[capture.id] is Unsynced) {
        changes[capture.id] = SyncStatus.inProgress();
        _sync.requests.add(capture);
      }
    }

    _updateStatuses(changes);
  }

  /// Takes in a client-to-host message and performs the corresponding
  /// operation, potentially adding one or more outgoing messages.
  void handle(ClientToHostMessage message) async {
    await message.when(
        requestAuth: _handleRequestAuth,
        latestCaptures: _handleLatestCaptures,
        requestSync: _handleRequestSync,
        requestSyncAll: _handleRequestSyncAll);
  }
}
