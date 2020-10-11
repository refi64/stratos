/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// Bindings to some chrome.identity APIs.
@JS('chrome.identity')
library stratos.chrome.identity;

import 'dart:async';

import 'package:js/js.dart';

@JS()
@anonymous
class _AuthTokenOptions {
  external bool get interactive;
  external List<String> get scopes;

  external factory _AuthTokenOptions({bool interactive, List<String> scopes});
}

class AuthTokenResult {
  final String token;
  final List<String> scopes;

  AuthTokenResult({this.token, this.scopes});
}

@JS('getAuthToken')
external void _getAuthToken(_AuthTokenOptions options, dynamic callback);

/// Gets an active Google auth token for [scopes], returning `null` on failure.
/// If the tokens are missing or expired, and [interactive] is true, new auth
/// privileges will attempt to be gained.
Future<AuthTokenResult> getAuthToken({bool interactive, List<String> scopes}) {
  final completer = Completer<AuthTokenResult>();
  _getAuthToken(
      _AuthTokenOptions(interactive: interactive, scopes: scopes),
      allowInterop(([String token, List<String> scopes]) => completer.complete(
          token != null
              ? AuthTokenResult(token: token, scopes: scopes)
              : null)));
  return completer.future;
}
