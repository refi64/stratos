/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// Manages authentication with Google.
library stratos.auth;

import 'dart:async';

import 'package:googleapis_auth/auth_browser.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'package:stratos/chrome/identity.dart' as chrome_identity;
import 'package:stratos/log.dart';

class AuthService {
  final _hasAuthController = StreamController<bool>.broadcast();

  /// A stream of the current auth status.
  Stream<bool> get hasAuth => _hasAuthController.stream;

  /// Asks the system to update and return the latest access credentials,
  /// or null if auth failed.
  Future<AccessCredentials> updateCredentials() async {
    var result = await _updateToken(interactive: false);
    if (result == null) {
      return null;
    }

    // XXX: AccessCredentials requires an expiration time, but we don't handle
    // that; Chrome does. Therefore, just pass the year 9999, and hopefully this
    // extension doesn't still exist by then. I mean, the way 2020 is going, it
    // would be pretty surprising...
    return AccessCredentials(
        AccessToken('Bearer', result.token, DateTime.utc(9999)),
        // No refresh token, because Chrome manages that.
        null,
        result.scopes ?? []);
  }

  /// Asks the system to send the latest authentication information.
  Future<void> sendAuthStatus() async {
    await _updateToken(interactive: false);
  }

  /// Notifies all listeners that a re-auth is required due to invalid
  /// credentials.
  Future<void> reportNonWorkingCredentials(
      AccessCredentials credentials) async {
    await chrome_identity.removeCachedAuthToken(
        token: credentials.accessToken.data);
    _hasAuthController.add(false);
  }

  /// Asks the system to run an interactive request for authentication.
  Future<void> runInteractiveAuthRequest() async {
    await _updateToken(interactive: true);
  }

  /// Asks the system for the latest auth token result from Chrome and notifies
  /// all listeners of the result. If authentication fails, returns null.
  /// If [interactive] is true and no auth token is present, the user will be
  /// interactively asked to log in.
  Future<chrome_identity.AuthTokenResult> _updateToken(
      {@required bool interactive}) async {
    chrome_identity.AuthTokenResult result;
    try {
      result = await chrome_identity.getAuthToken(interactive: interactive);
    } on chrome_identity.AuthTokenError catch (ex) {
      logger.i('Could not acquire auth token: $ex');
    }

    _hasAuthController.add(result != null);
    return result;
  }
}

class MissingAuthException implements Exception {
  MissingAuthException();
  @override
  String toString() => 'Missing auth';
}

/// An [http.BaseClient] that passes auth credentials that are derived from the
/// Chrome identity API.
class ChromeAuthClient extends http.BaseClient {
  final http.Client base;
  final AuthService authService;
  ChromeAuthClient(this.base, this.authService);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var credentials = await authService.updateCredentials();
    if (credentials == null) {
      throw MissingAuthException();
    }

    var delegate = authenticatedClient(base, credentials);
    try {
      return await delegate.send(request);
    } on AccessDeniedException {
      await authService.reportNonWorkingCredentials(credentials);
      throw MissingAuthException();
    }
  }
}
