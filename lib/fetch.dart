/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// `package:http`'s default client for the web does not support streaming the
/// response, as `XMLHttpRequest` did not support it. We need streaming
/// responses for progress monitoring of an upload, however, so a custom client
/// is used that uses the newer browser `fetch` APIs, which *do* support
/// streaming responses.
///
/// Unfortunately, `@JS()`-based, nice types cannot be used for interop here due
/// to the following Dart SDK bugs:
/// https://github.com/dart-lang/sdk/issues/35751
/// https://github.com/dart-lang/sdk/issues/38099
/// Therefore, `dynamic`s are used extensively.
@JS()
library stratos.fetch_client;

import 'dart:async';
import 'dart:html';
import 'dart:html_common';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:js/js.dart';
import 'package:js/js_util.dart';

/// The next chunk of a `ReadableStreamDefaultReader`.
@JS()
class _JsNextChunk {
  @anonymous
  external bool get done;
  external Uint8List get value;
}

@JS('Array.from')
external List _arrayFrom(dynamic from);

class FetchBrowserClient extends http.BaseClient {
  final _contentLengthHeader = 'content-length';

  bool withCredentials = false;

  /// Reads the content of a `ReadableStreamDefaultReader` and forwards it to
  /// the [controller].
  Future<void> _readStreams(
      dynamic reader, StreamController<Uint8List> controller) async {
    for (;;) {
      var next =
          await promiseToFuture<_JsNextChunk>(callMethod(reader, 'read', []));
      if (next.done) {
        await controller.close();
        break;
      }

      controller.add(next.value);
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var bytes = await request.finalize().toBytes();

    dynamic response;
    try {
      response = await window.fetch(request.url, <String, dynamic>{
        'method': request.method,
        'credentials': withCredentials ? 'include' : 'same-origin',
        'redirect': request.followRedirects ? 'follow' : 'manual',
        'headers': convertDartToNative_Dictionary(request.headers),
        'body': bytes.isNotEmpty ? bytes : null,
      });
    } catch (ex) {
      throw http.ClientException('fetch error: $ex', request.url);
    }

    dynamic body = getProperty(response, 'body');
    var controller = StreamController<Uint8List>();

    // ignore: unawaited_futures
    _readStreams(callMethod(body, 'getReader', []), controller);

    var responseHeaders = <String, String>{
      for (var pair
          in _arrayFrom(getProperty(response, 'headers')).cast<List>())
        pair[0] as String: pair[1] as String
    };

    return http.StreamedResponse(
        controller.stream, getProperty(response, 'status') as int,
        contentLength: int.tryParse(responseHeaders[_contentLengthHeader]),
        request: request,
        headers: responseHeaders,
        isRedirect: getProperty(response, 'redirected') as bool,
        reasonPhrase: getProperty(response, 'statusText') as String);
  }
}
