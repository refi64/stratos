/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'package:rxdart/rxdart.dart';
import 'package:stratos/auth.dart';
import 'package:stratos/message.dart';
import 'package:stratos/drizzle/controller.dart';
import 'package:stratos/drizzle/template.dart';
import 'package:stratos/popup/login.dart';
import 'package:stratos/popup/progress.dart';

/// The current authentication state. Used to figure out whether or not the
/// sign in button should be shown.
enum AuthState { loggedIn, inProgress, loggedOut }

/// A Drizzle controller that is the top level popup UI.
class AppController extends Controller {
  static final factory =
      ControllerFactory<AppController>('app', () => AppController._());

  final authState = BehaviorSubject<AuthState>();

  final pipe = ClientSideMessagePipe(PortMessagePipeDelegate.connect());

  TemplateController _contentController;

  AppController._() {
    testNeedsReauth().then(_updateAuthState);
    watchNeedsReauth().listen(_updateAuthState);

    authState.listen((state) {
      if (state == AuthState.loggedIn) {
        _replaceControllerIfNotSame(() => ProgressController());
      } else {
        _replaceControllerIfNotSame(() => LoginController());
      }
    });
  }

  void _updateAuthState(bool needsReauth) {
    authState.add(needsReauth ? AuthState.loggedOut : AuthState.loggedIn);
  }

  /// Replaces the current child element controller if it is not already an
  /// instance of the desired one.
  void _replaceControllerIfNotSame<C extends TemplateController>(
      C Function() factory) {
    if (_contentController is! C) {
      _contentController = factory();
      _contentController.instantiateReplacing(element.children.first);
    }
  }
}
