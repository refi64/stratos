/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// Bindings to some chrome.identity APIs.
@JS('chrome.identity')
library stratos.chrome.identity;

import 'dart:async';

import 'package:js/js.dart';
import 'package:meta/meta.dart';

import 'runtime.dart' as chrome_runtime;

@JS()
@anonymous
class _AuthTokenOptions {
  external bool get interactive;
  external List<String> get scopes;

  external factory _AuthTokenOptions({bool interactive, List<String> scopes});
}

@JS()
@anonymous
class _RemoveTokenOptions {
  external String get token;

  external factory _RemoveTokenOptions({String token});
}

class AuthTokenResult {
  final String token;
  final List<String> scopes;

  AuthTokenResult({this.token, this.scopes});
}

class AuthTokenError implements Exception {
  String message;
  AuthTokenError(this.message);
  @override
  String toString() => message;
}

@JS('getAuthToken')
external void _getAuthToken(_AuthTokenOptions options, dynamic callback);

@JS('removeCachedAuthToken')
external void _removeCachedAuthToken(
    _RemoveTokenOptions options, dynamic callback);

/// Gets an active Google auth token for [scopes], returning `null` on failure.
/// If the tokens are missing or expired, and [interactive] is true, new auth
/// privileges will attempt to be gained. On failure, [AuthTokenError] may also
/// be thrown.
/// XXX: not sure if it's possible for the token to be undefined but
/// [runtime.lastError] was undefined.
Future<AuthTokenResult> getAuthToken({bool interactive, List<String> scopes}) {
  final completer = Completer<AuthTokenResult>();
  _getAuthToken(_AuthTokenOptions(interactive: interactive, scopes: scopes),
      allowInterop(([String token, List<String> scopes]) {
    if (token == null && chrome_runtime.lastError != null) {
      completer.completeError(AuthTokenError(chrome_runtime.lastError.message));
    } else {
      completer.complete(
          token != null ? AuthTokenResult(token: token, scopes: scopes) : null);
    }
  }));
  return completer.future;
}

Future<void> removeCachedAuthToken({@required String token}) {
  final completer = Completer<void>();
  _removeCachedAuthToken(_RemoveTokenOptions(token: token),
      allowInterop(() => completer.complete()));
  return completer.future;
}
