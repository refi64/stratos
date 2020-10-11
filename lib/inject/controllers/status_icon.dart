/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

import 'package:meta/meta.dart';
import 'package:stratos/drizzle/template.dart';
import 'package:stratos/drizzle/utils.dart';
import 'package:stratos/inject/controllers/inject.dart';
import 'package:stratos/message.dart';

/// A Drizzle controller that is potentially attached to an individual capture
/// element and allows to start a synchronization.
class StatusIconController extends TemplateController {
  /// A synthetic ID that signifies that, on click, *all* captures should be
  /// synced.
  static final idSyncAll = '__all__';

  @override
  String get template => 'status-icon';

  /// The capture ID.
  final String id;

  /// The DOM element holding the material icon.
  Element _icon;

  /// The DOM element holding the current upload percentage.
  Element _percent;

  StatusIconController({@required this.id}) {
    installActions({'upload': _upload});
  }

  @override
  void onAttach() {
    _icon = element.querySelector('.google-material-icons');
    _percent = element.querySelector('.stratos-status-percent');
  }

  /// Updates the current icon state to match the given status.
  void updateStatus(SyncStatus status) {
    // XXX: Currently, syncing all captures through here is unsupported. Why? I
    // have no freaking idea. It was weird and I didn't want to mess with it.
    // IIRC, the user was able to click it and request a full sync before all
    // the statuses were checked, which was somewhat bizarre behavior. This
    // really should be fixed...
    if (status is Unsynced && id != idSyncAll) {
      element.classes.remove('stratos-status-icon-non-interactive');
    } else {
      element.classes.add('stratos-status-icon-non-interactive');
    }

    // If progress is active, hide the icon completely and only show the
    // progress.
    if (status is InProgress && status.progress != null) {
      _icon.hide();
      _percent.show();
      _percent.innerText = '${(status.progress * 100).truncate()}%';
    } else {
      _icon.show();
      _percent.hide();

      var icon = status.when(
          unsynced: () => 'cloud_upload',
          inProgress: (_) => 'sync',
          complete: () => 'check_circle');

      _icon.innerText = icon;

      // This is down here to ensure animating the progress icon doesn't occur
      // if a textual percentage is shown.
      if (status is InProgress) {
        element.classes.add('stratos-status-icon-progress');
      } else {
        element.classes.remove('stratos-status-icon-progress');
      }
    }
  }

  void _upload(Element button, Event event) {
    updateStatus(SyncStatus.inProgress());

    var inject =
        findParentByName<InjectController>(InjectController.factoryName);
    inject.pipe.outgoing.add(id == idSyncAll
        ? ClientToHostMessage.requestSyncAll()
        : ClientToHostMessage.requestSync(id));
  }
}
