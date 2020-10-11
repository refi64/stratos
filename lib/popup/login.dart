/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

import 'package:stratos/auth.dart';
import 'package:stratos/message.dart';
import 'package:stratos/drizzle/template.dart';
import 'package:stratos/popup/app.dart';

/// A Drizzle controller that shows a login UI.
class LoginController extends TemplateController {
  LoginController() {
    installActions({'login': login});
  }

  void login(Element el, Event event) async {
    await setNeedsReauth(true);

    var app = findParentByFactory(AppController.factory);
    app.authState.add(AuthState.inProgress);
    app.pipe.outgoing.add(ClientToHostMessage.requestAuth());
  }

  @override
  String get template => 'login';
}
