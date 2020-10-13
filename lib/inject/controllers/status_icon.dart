/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
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

  /// The stream of new statuses. `null` is used for [idSyncAll] to show that
  /// the status of different captures is still being checked.
  final _statusSubject = BehaviorSubject<SyncStatus>.seeded(null);

  /// A sink for adding new statuses.
  StreamSink<SyncStatus> get statuses => _statusSubject.sink;

  /// The stream of the sync availability.
  final _syncAvailabilitySubject = BehaviorSubject<bool>.seeded(true);

  /// A sink for updating the sync availability.
  StreamSink<bool> get syncAvailability => _syncAvailabilitySubject.sink;

  StatusIconController({@required this.id}) {
    installActions({'upload': _upload});

    _statusSubject.listen((_) => _update());
    _syncAvailabilitySubject.listen((_) => _update());
  }

  @override
  void onAttach() {
    _icon = element.querySelector('.google-material-icons');
    _percent = element.querySelector('.stratos-status-percent');
  }

  void _update() {
    var status = _statusSubject.value;

    if (status is Unsynced) {
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

      var syncDisabled = !_syncAvailabilitySubject.value;
      var icon = syncDisabled
          ? 'sync_disabled'
          : (status?.when(
                  unsynced: () => 'cloud_upload',
                  inProgress: (_) => 'sync',
                  complete: () => 'check_circle') ??
              'sync');

      _icon.innerText = icon;

      // This is down here to ensure animating the progress icon doesn't occur
      // if a textual percentage is shown.
      if (icon == 'sync') {
        element.classes.add('stratos-status-icon-progress');
      } else {
        element.classes.remove('stratos-status-icon-progress');
      }
    }
  }

  void _upload(Element button, Event event) {
    statuses.add(SyncStatus.inProgress());

    var inject =
        findParentByName<InjectController>(InjectController.factoryName);
    inject.pipe.outgoing.add(id == idSyncAll
        ? ClientToHostMessage.requestSyncAll()
        : ClientToHostMessage.requestSync(id));
  }
}
