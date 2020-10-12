/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'package:stratos/message.dart';
import 'package:stratos/drizzle/controller.dart';
import 'package:stratos/drizzle/template.dart';
import 'package:stratos/popup/login.dart';
import 'package:stratos/popup/progress.dart';

/// A Drizzle controller that is the top level popup UI.
class AppController extends Controller {
  static final factory =
      ControllerFactory<AppController>('app', () => AppController._());

  final pipe = ClientSideMessagePipe(PortMessagePipeDelegate.connect());

  TemplateController _contentController;

  AppController._() {
    pipe.onMessage.listen((message) => message.when(
        syncAvailability: _updateSyncAvailability,
        updateCaptureStatuses: _updateCaptureStatuses));
  }

  void _updateSyncAvailability(bool available) {
    if (available) {
      _replaceControllerIfNotSame(() => ProgressController());
    } else {
      _replaceControllerIfNotSame(() => LoginController());
    }
  }

  void _updateCaptureStatuses(Map<String, CaptureSyncStatus> statuses) {
    if (_contentController is ProgressController) {
      (_contentController as ProgressController)
          .updatedCaptureStatuses
          .add(statuses);
    }
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
