/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// This is used to intercept XMLHttpRequest in order to pick up calls to the
/// Stadia captures API.
@JS()
library stratos.inject.xhr;

import 'dart:async';

import 'package:js/js.dart';
import 'package:js/js_util.dart';

import 'package:stratos/log.dart';

@JS('XMLHttpRequest.prototype')
class _XhrPrototype {
  external static dynamic get open;
  external static set open(dynamic value);

  external static dynamic get send;
  external static set send(dynamic value);

  // Used to store the original functions.
  external static dynamic get oldOpen;
  external static set oldOpen(dynamic value);

  external static dynamic get oldSend;
  external static set oldSend(dynamic value);
}

class XhrResponse {
  final dynamic response;
  XhrResponse._(this.response);
}

class XhrRequestFailure implements Exception {
  final String url;
  XhrRequestFailure(this.url);

  @override
  String toString() => 'XHR request to $url failed';
}

class XhrRequest {
  Future<XhrResponse> response() {
    var completer = Completer<XhrResponse>();

    callMethod(_request, 'addEventListener', [
      'load',
      allowInterop((dynamic _) {
        completer.complete(XhrResponse._(_request.response));
      })
    ]);

    callMethod(_request, 'addEventListener', [
      'error',
      allowInterop((dynamic _) {
        completer.completeError(XhrRequestFailure(_request.url as String));
      })
    ]);

    return completer.future;
  }

  static const _urlProperty = 'stratosUrl';

  final dynamic _request;
  XhrRequest._(this._request);

  String get url => getProperty(_request, _urlProperty) as String;

  static void _setUrl(dynamic request, String url) {
    setProperty(request, _urlProperty, url);
  }
}

Stream<XhrRequest> interceptRequests() {
  StreamController<XhrRequest> controller;
  controller = StreamController<XhrRequest>.broadcast(
    onListen: () {
      _XhrPrototype.oldOpen = _XhrPrototype.open;
      _XhrPrototype.oldSend = _XhrPrototype.send;

      _XhrPrototype.open = allowInteropCaptureThis(
          (dynamic xhr, dynamic method, String url,
              [dynamic async_, dynamic user, dynamic pass]) {
        XhrRequest._setUrl(xhr, url);
        callMethod(xhr, 'oldOpen', [method, url, async_, user, pass]);
      });

      _XhrPrototype.send =
          allowInteropCaptureThis((dynamic xhr, [dynamic body]) {
        handleErrors('Error processing interop event', () {
          controller.add(XhrRequest._(xhr));
          callMethod(xhr, 'oldSend', [body]);
        });
      });
    },
    onCancel: () {
      _XhrPrototype.open = _XhrPrototype.oldOpen;
      _XhrPrototype.send = _XhrPrototype.oldSend;
    },
  );

  return controller.stream;
}
