/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:async';
import 'dart:collection';
import 'dart:html';

import 'package:stratos/chrome/tabs.dart' as chrome_tabs;
import 'package:stratos/drizzle/application.dart';
import 'package:stratos/message.dart';
import 'package:stratos/drizzle/controller.dart';
import 'package:stratos/drizzle/template.dart';
import 'package:stratos/drizzle/utils.dart';
import 'package:stratos/popup/row.dart';
import 'package:stratos/popup/tabs.dart';

/// A Drizzle controller that shows a list of known captures and any progress
/// being taken to upload them.
class ProgressController extends TemplateController {
  @override
  String get template => 'progress';

  final _updatedCaptureStatusesController =
      StreamController<Map<String, CaptureSyncStatus>>();

  /// Output sink to place updated captures into.
  StreamSink<Map<String, CaptureSyncStatus>> get updatedCaptureStatuses =>
      _updatedCaptureStatusesController.sink;

  /// The DOM ID of the tab for unsynced captures.
  static const _unsyncedTabId = 'unsynced';

  /// The DOM ID of the tab for synced captures.
  static const _syncedTabId = 'synced';

  /// The tab row.
  Element _tabRow;

  /// The view for the contents of the currently active tab.
  Element _view;

  TabsController _tabsController;

  final _statuses = <String, CaptureSyncStatus>{};

  /// The rows in the current tab. A [SplayTreeMap] is used to ensure that it is
  /// always ordered.
  SplayTreeMap<String, RowController> _currentTabRows;

  /// The row that shows a currently uploading capture.
  RowController _uploadingRow;

  ProgressController() {
    // Rows are sorted by their creation date, newest on top.
    _currentTabRows = SplayTreeMap((a, b) =>
        _statuses[b].capture.creation.compareTo(_statuses[a].capture.creation));

    installActions({
      'goToCaptures': _goToCaptures,
      'switchTab': (el, event) => _setActive(el.id),
    });

    _updatedCaptureStatusesController.stream.listen(_onUpdatedCaptures);
  }

  @override
  void onAttach() {
    _tabRow = element.querySelector('#tabs');
    _view = element.querySelector('#view');
  }

  @override
  void onReady() {
    _tabsController = Controller.ofElement<Element, TabsController>(_tabRow);
    _tabsController.onSwitch.listen(_setActive);
  }

  String get _activeTabId => _tabsController.active;
  String get _inactiveTabId =>
      _activeTabId == _syncedTabId ? _unsyncedTabId : _syncedTabId;

  /// Determines whether or not a capture with the given [status] should go in
  /// the tab that is currently active.
  bool _goesInActiveTab(SyncStatus status) {
    if (_activeTabId == _unsyncedTabId) {
      // In-progress ones will go in the unsynced tab if they do not yet have a
      // progress percentage (that condition is handled elsewhere).
      return status is InProgress || status is Unsynced;
    } else {
      return status is Complete;
    }
  }

  void _onUpdatedCaptures(Map<String, CaptureSyncStatus> updates) {
    for (var entry in updates.entries) {
      if (_statuses[entry.key]?.status != entry.value.status) {
        _statuses[entry.key] = entry.value;

        // If this has a progress percentage, it goes in the
        // "currently uploading" area.
        var goesInUploadSection = entry.value.status is InProgress &&
            (entry.value.status as InProgress).progress != null;

        if (goesInUploadSection) {
          if (_uploadingRow?.capture?.id != entry.key) {
            // Clear any previous rows in the "uploading" section.
            if (_uploadingRow != null) {
              _clearUploadingRow();
            }

            // If this row was already in a different area, remove it from there.
            if (_currentTabRows.containsKey(entry.key)) {
              _removeRow(entry.key);
            }

            _uploadingRow = RowController(entry.value.capture)
              ..instantiateInto(element.querySelector('#uploading-row'));
          }

          _uploadingRow.percent
              .add((entry.value.status as InProgress).progress);
        } else {
          if (_uploadingRow?.capture?.id == entry.key) {
            // No longer in the "uploading" state, so remove from that area.
            _clearUploadingRow();
          }

          if (_goesInActiveTab(entry.value.status)) {
            // Add this new row if it's not already present.
            if (!_currentTabRows.containsKey(entry.key)) {
              _addRow(entry.key);
            }
          } else {
            // No longer visible in the current tab or in the upload section, so
            // remove it if needed.
            if (_currentTabRows.containsKey(entry.key)) {
              _removeRow(entry.key);
            }
          }
        }
      }
    }

    _postUpdate();
  }

  /// Adds a new row with the given ID to the current tab.
  RowController _addRow(String id) {
    var row = RowController(_statuses[id].capture);
    _currentTabRows[id] = row;

    // Make sure it goes in the right place, given the ordering defined by the
    // map.
    var siblingId = _currentTabRows.firstKeyAfter(id);
    var sibling = siblingId != null ? _currentTabRows[siblingId].element : null;
    row.instantiateInto(_view, before: sibling);
    return row;
  }

  /// Removes a row from the current tab.
  void _removeRow(String id) {
    var row = _currentTabRows.remove(id);
    var element = row.element;
    Application.detach(element);
    element.remove();
  }

  /// Clears out the contents of the "currently uploading" row.
  void _clearUploadingRow() {
    var uploadingElement = _uploadingRow.element;
    Application.detach(uploadingElement);
    _uploadingRow = null;
    uploadingElement.remove();
  }

  void _goToCaptures(Element link, Event event) {
    chrome_tabs.create(url: 'https://stadia.google.com/captures', active: true);
  }

  /// Sets the rows to match the new active tab, [tabId].
  void _setActive(String tabId) {
    // .toList() to avoid modifying the map while iterating over it.
    _currentTabRows.keys.toList().forEach(_removeRow);
    element.querySelector('#$_inactiveTabId-empty').hide();

    var matchingEntries = _statuses.entries
        .where((entry) => _goesInActiveTab(entry.value.status));
    for (var entry in matchingEntries) {
      _addRow(entry.key);
    }

    _postUpdate();
  }

  void _postUpdate() {
    var allEmptyText = element.querySelector('#all-empty');
    var tabEmptyText = element.querySelector('#$_activeTabId-empty');
    var uploadingEmptyText = element.querySelector('#uploading-empty');

    if (_statuses.isEmpty) {
      allEmptyText.show();
      tabEmptyText.hide();
    } else {
      allEmptyText.hide();

      if (_currentTabRows.isNotEmpty) {
        tabEmptyText.hide();
      } else {
        tabEmptyText.show();
      }

      if (_uploadingRow != null) {
        uploadingEmptyText.hide();
      } else {
        uploadingEmptyText.show();
      }
    }
  }
}
