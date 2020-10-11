/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// Manages authentication with Google.
/// NOTE: This whole thing is a complete hack. Really, authentication should
/// probably always be interactive. Instead, there's this weird double system,
/// where the current status is saved in storage which is watched but also sent
/// over the message pipes.
library stratos.auth;

import 'package:googleapis_auth/auth_browser.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

import 'package:stratos/chrome/identity.dart' as chrome_identity;
import 'package:stratos/chrome/storage.dart' as chrome_storage;

class MissingAuthException implements Exception {
  MissingAuthException();
  @override
  String toString() => 'Missing auth';
}

/// An [http.BaseClient] that passes auth credentials that are derived from the
/// Chrome identity API.
class ChromeAuthClient extends http.BaseClient {
  final http.Client base;
  ChromeAuthClient(this.base);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var credentials = await obtainCredentials();
    if (credentials == null) {
      // Signify to all watchers that we need re-authentication.
      await setNeedsReauth(true);
      throw MissingAuthException();
    }

    var delegate = authenticatedClient(base, credentials);
    return await delegate.send(request);
  }
}

/// Obtains the [AccessCredentials] to log in to Google. If [interactive] is
/// `true`, and there are no valid credentials, then the user will be asked
/// interactively to log in. Otherwise, or if an error occurs, `null` is
/// returned.
Future<AccessCredentials> obtainCredentials({bool interactive = false}) async {
  var result = await chrome_identity.getAuthToken(interactive: interactive);
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

final _NEEDS_REAUTH_STORAGE_KEY = 'needs-reauth';

// Due to the weird double-system we have, whether or not the client needs a
// re-auth is stored in storage, but whenever we test it, we also need to make
// sure something didn't break and we actually already have credentials.

/// Tests whether or not a re-auth is required.
Future<bool> testNeedsReauth() async {
  var needsReauth =
      await chrome_storage.local.get(_NEEDS_REAUTH_STORAGE_KEY) != null;
  if (needsReauth && await obtainCredentials() == null) {
    needsReauth = true;
    await setNeedsReauth(needsReauth);
  }

  return needsReauth;
}

/// Tells the system that a re-auth is required.
Future<void> setNeedsReauth(bool status) async => status
    ? await chrome_storage.local.put(_NEEDS_REAUTH_STORAGE_KEY, 'yes')
    : chrome_storage.local.remove(_NEEDS_REAUTH_STORAGE_KEY);

/// Watches the state of the re-auth requirement key.
Stream<bool> watchNeedsReauth() => chrome_storage.onChanged.flatMap((event) {
      if (event.namespace == 'local' &&
          event.changes.containsKey(_NEEDS_REAUTH_STORAGE_KEY)) {
        var newData = event.changes[_NEEDS_REAUTH_STORAGE_KEY].newValue;
        return Stream.value(newData != null);
      } else {
        return Stream.empty();
      }
    });
