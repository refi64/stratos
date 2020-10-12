/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:http/http.dart' as http;
import 'package:stratos/background/auth.dart';
import 'package:stratos/fetch.dart';
import 'package:stratos/log.dart';

import '../capture.dart';
import '../message.dart';

// XXX: This should be user-configurable at some point.
final _directoryName = 'Stadia Captures';

final _directoryMimeType = 'application/vnd.google-apps.folder';

final _contentTypeHeader = 'content-type';

final _capturesDirProperty = 'is-captures';
final _capturesDirValue = 'yes';
final _gameNameProperty = 'game-name';
final _captureIdProperty = 'capture-id';

/// The actual sync engine implementation.
class SyncService {
  final _client = FetchBrowserClient();
  DriveApi _api;

  SyncService(AuthService authService) {
    _api = DriveApi(ChromeAuthClient(_client, authService));
    _startSyncService();
  }

  // This handles each capture one at a time. That way, if there is some break
  // in testing for already-uploaded images, duplicates will still never be
  // a problem.
  void _startSyncService() async {
    await for (var capture in _requestController.stream) {
      await handleErrorsMaybeAsync(
          'Uploading capture ${capture.id}', () => _runSync(capture));
    }
  }

  void close() {
    _requestController.close();
    _progressController.close();
  }

  /// Escapes a string value to be passed to a Drive API query.
  String _escapeQueryValue(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

  /// Searches for a file with the given query parameters set. On failure,
  /// returns null.
  Future<File> _searchForFile(
      {String parent,
      String name,
      String mimeType,
      Map<String, String> appProperties}) async {
    var query = <String>[];
    if (parent != null) {
      query.add("'${_escapeQueryValue(parent)}' in parents");
    }
    if (name != null) {
      query.add("name = '${_escapeQueryValue(name)}'");
    }
    if (mimeType != null) {
      query.add("mimeType = '${_escapeQueryValue(mimeType)}'");
    }
    if (appProperties != null) {
      for (var property in appProperties.entries) {
        query.add('appProperties has '
            "  { key = '${_escapeQueryValue(property.key)}'"
            "and value = '${_escapeQueryValue(property.value)}' }");
      }
    }

    var matches = await _api.files.list(
        corpora: 'user',
        pageSize: 1,
        q: query.join(' and '),
        $fields: 'files(id)');
    return matches.files.isNotEmpty ? matches.files.first : null;
  }

  /// Performs a search for a directory with the given parameters, returning it
  /// if found, or creating one with the parameters and returning it otherwise.
  Future<File> _getOrCreateDirectory(
      {@required String name,
      String parent,
      Map<String, String> appProperties}) async {
    var directory = await _searchForFile(
        parent: parent,
        appProperties: appProperties,
        mimeType: _directoryMimeType);
    if (directory != null) {
      return directory;
    } else {
      var request = File()
        ..name = name
        ..mimeType = _directoryMimeType
        ..parents = parent != null ? [parent] : null
        ..appProperties = appProperties;
      return await _api.files
          .create(request, enforceSingleParent: true, $fields: 'id');
    }
  }

  /// Checks if the given capture is already synced.
  Future<bool> alreadySynced(String captureId) async {
    var file =
        await _searchForFile(appProperties: {_captureIdProperty: captureId});
    return file != null;
  }

  /// Runs a sync operation for the given capture.
  void _runSync(Capture capture) async {
    var success = false;

    try {
      if (await alreadySynced(capture.id)) {
        logger.i('Avoiding duplicate upload of ${capture.id}');
        return;
      }

      var root = await _getOrCreateDirectory(
          name: _directoryName,
          appProperties: {_capturesDirProperty: _capturesDirValue});
      var game = await _getOrCreateDirectory(
          parent: root.id,
          name: capture.game,
          appProperties: {_gameNameProperty: capture.game});

      var request = http.Request('GET', Uri.parse(capture.url));
      var response = await _client.send(request);

      var contentType = response.headers[_contentTypeHeader];

      // Send progress updates as data is read.
      var readBytes = 0;
      var progressStream = response.stream.map((List<int> bytes) {
        handleErrors('Sending progress updates for ${capture.id}', () {
          readBytes += bytes.length;
          var progress = readBytes / response.contentLength;
          logger.d('Adding progress: $readBytes of ${response.contentLength}');
          _progressController
              .add(CaptureSyncStatus(capture, SyncStatus.inProgress(progress)));
        });
        return bytes;
      });

      // debugging helper
      // await progressStream.last;

      var media = Media(progressStream, response.contentLength,
          contentType: contentType);

      var file = File()
        ..name = capture.creation.toString().split('.')[0]
        ..mimeType = contentType
        ..parents = [game.id]
        ..createdTime = capture.creation.toUtc()
        ..appProperties = {_captureIdProperty: capture.id};
      await _api.files.create(file,
          enforceSingleParent: true,
          uploadOptions: UploadOptions.Default,
          uploadMedia: media,
          $fields: 'id');

      success = true;
    } finally {
      _progressController.add(CaptureSyncStatus(
          capture, success ? SyncStatus.complete() : SyncStatus.unsynced()));
    }
  }

  final _requestController = StreamController<Capture>();
  StreamSink<Capture> get requests => _requestController.sink;

  final _progressController = StreamController<CaptureSyncStatus>();
  Stream<CaptureSyncStatus> get onProgress => _progressController.stream;
}
