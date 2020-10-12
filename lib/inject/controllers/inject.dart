/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

import 'package:meta/meta.dart';
import 'package:stratos/drizzle/controller.dart';
import 'package:stratos/inject/controllers/status_icon.dart';
import 'package:stratos/log.dart';
import 'package:stratos/message.dart';
import '../assets.dart';
import 'header.dart';

/// A Drizzle controller that attaches to the root body and manages all the
/// status icons and such inside.
/// XXX: This shouldn't be called "app", that makes no sense.
class InjectController extends Controller<BodyElement> {
  static const factoryName = 'app';
  static ControllerFactory<InjectController> createFactory(
          ClientSideMessagePipe pipe) =>
      ControllerFactory(factoryName, () => InjectController._(pipe));

  final ClientSideMessagePipe pipe;
  final _allStatuses = <String, CaptureSyncStatus>{};

  final _headerController = HeaderController();

  /// This attribute is set on all capture grid members that have a status icon
  /// attached, so we can quickly see if there are any that don't have an icon.
  static const _hasSyncIconAttribute = 'stratos-has-sync-icon';

  bool _needsAuth = false;
  MutationObserver _observer;

  InjectController._(this.pipe) {
    pipe.onMessage.listen(_handleMessage);
  }

  @override
  void onAttach() {
    element.appendHtml(injectedHtml.text,
        treeSanitizer: NodeTreeSanitizer.trusted);

    // This is the "Captures" heading at the top of the page.
    var capturesHeading = element.querySelector('.CVVXfc.L7zYPb');
    _headerController.instantiateInto(capturesHeading);

    // This is the grid of all the individual captures.
    var capturesGrid = element.querySelector('.au9T5d');

    // Okay: so there's a potential data race here. When we send the total list
    // of captures to the host, it may reply *before* all the DOM nodes have
    // been added. To handle that scenario, a mutation observer is used that
    // will update the status icon controller of any new nodes if the host
    // response came first.
    _observer = MutationObserver((mutations, observer) {
      for (var mutation in mutations.cast<MutationRecord>()) {
        assert(mutation.type == 'childList');
        mutation.addedNodes.whereType<Element>().forEach(_updateStatus);
      }
    });
    _observer.observe(capturesGrid, childList: true);
  }

  @override
  void onDetach() {
    _observer.disconnect();
  }

  /// Takes any sync availability update messages and notifies the user if
  /// needed.
  void _updateSyncAvailability(bool enabled) {
    logger.d('New sync availability: $enabled');

    if (!enabled) {
      _headerController.syncAvailability.add(false);
      _needsAuth = true;
    } else if (_needsAuth) {
      // Managing all of this state is hard, so reloading on auth is easier...
      window.location.reload();
    }
  }

  /// Returns a [StatusIconController] if one has been attached to [parent]
  /// already, otherwise creates a new one passing the given [id].
  StatusIconController _getOrInstantiateStatusIcon(
      {@required Element parent, @required String id}) {
    var injected = parent.querySelector('.stratos-injected');
    if (injected != null) {
      return Controller.ofElement<Element, StatusIconController>(injected);
    }

    var controller = StatusIconController(id: id);
    controller.instantiateInto(parent);
    parent.setAttribute(_hasSyncIconAttribute, '');
    return controller;
  }

  /// Updates the status icon controller of the given capture element of the
  /// grid.
  void _updateStatus(Element captureElement) {
    var id = captureElement.getAttribute('data-capture-id');
    if (!_allStatuses.containsKey(id)) {
      logger.d('Have not received status for capture ID: $id');
      return;
    }

    var controller =
        _getOrInstantiateStatusIcon(parent: captureElement, id: id);
    controller.statuses.add(_allStatuses[id].status);
  }

  /// Updates the header at the very top of the page. If [hintOneInProgress]
  /// is given, it means at least one capture upload is guaranteed to be in
  /// progress.
  void _updateHeader({bool hintOneInProgress}) {
    // The capture icon at the top has five states:
    // - Shows the sync disabled icon & some status text if auth is required.
    // - Shows the progress icon & some status text if not all grid items have
    //   icons attached.
    // - Shows the progress icon if a sync is underway.
    // - Shows the upload icon if at least one capture is not synced but no
    //   syncs is currently in progress.
    // - Shows the check if all are synced.
    // The first case is already handled elsewhere, and the second case is the
    // default state; we can check if it needs to remain that way quickly at
    // the very start.
    // Afterwards, if at least one capture is known to be in progress, the state
    // shown is *guaranteed* to be the progress icon. Thus, we can shortcut
    // scanning the captures list once we know at least one is in progress.

    if (element
            .querySelector('[data-capture-id]:not([$_hasSyncIconAttribute])') !=
        null) {
      return;
    }

    var atLeastOneInProgress = hintOneInProgress;
    var atLeastOneUnsynced = false;

    for (var captureStatus in _allStatuses.values) {
      if (atLeastOneInProgress) {
        break;
      }

      if (captureStatus.status is InProgress) {
        atLeastOneInProgress = true;
      } else if (captureStatus.status is Unsynced) {
        atLeastOneUnsynced = true;
      }
    }

    if (atLeastOneInProgress) {
      _headerController.statuses.add(SyncStatus.inProgress());
    } else if (atLeastOneUnsynced) {
      _headerController.statuses.add(SyncStatus.unsynced());
    } else {
      _headerController.statuses.add(SyncStatus.complete());
    }
  }

  /// Updates the currently known capture statuses.
  void _updateCaptureStatuses(Map<String, CaptureSyncStatus> newStatuses) {
    _allStatuses.addAll(newStatuses);

    var atLeastOneInProgress = false;

    for (var entry in newStatuses.entries) {
      logger.d('Handling updated ID: ${entry.key} ${entry.value.status}');

      var captureElement =
          document.querySelector('[data-capture-id="${entry.key}"]');
      if (captureElement == null) {
        logger.w('Missing element for capture ID: ${entry.key}');
        continue;
      }

      _updateStatus(captureElement);
      if (entry.value is InProgress) {
        atLeastOneInProgress = true;
      }
    }

    _updateHeader(hintOneInProgress: atLeastOneInProgress);
  }

  void _handleMessage(HostToClientMessage message) {
    message.when(
        updateCaptureStatuses: _updateCaptureStatuses,
        syncAvailability: _updateSyncAvailability);
  }
}
