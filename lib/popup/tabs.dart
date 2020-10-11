/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:async';
import 'dart:html';

import 'package:rxdart/rxdart.dart';
import 'package:stratos/drizzle/controller.dart';

/// A Drizzle controller that manages a row of tabs. The user *must* set
/// [ACTIVE_CLASS_ATTRIBUTE] on the attached DOM element to signify a CSS class
/// that will be added to the active tab.
/// Individual tabs should have `dz-actions="attach:tabs"` to signify their new
/// presence to the controller. In addition, tabs *must* not be removed without
/// destroying the entire tabs controller.
class TabsController extends Controller {
  static final factory = ControllerFactory('tabs', () => TabsController._());

  static final ACTIVE_CLASS_ATTRIBUTE = 'data-tabs-active-class';

  String _activeClass;
  final _tabs = <Element>{};

  TabsController._() {
    installActions({'attach': _tabAttach, 'click': _tabSwitch});
  }

  @override
  void onAttach() {
    _activeClass = element.getAttribute(ACTIVE_CLASS_ATTRIBUTE);
  }

  @override
  void onReady() {
    var active = element.querySelector(':scope > .$_activeClass');
    // Switch to the first tab if none has the active class.
    _tabSwitch(active ?? element.children.first);
  }

  final _switchSubject = BehaviorSubject<String>();
  String get active => _switchSubject.value;
  Stream<String> get onSwitch => _switchSubject.stream;

  void _tabAttach(Element tab, Event event) {
    _tabs.add(tab);
  }

  void _tabSwitch(Element tab, [Event event]) {
    for (var otherTab in _tabs) {
      if (tab == otherTab) {
        otherTab.classes.add(_activeClass);
        _switchSubject.add(tab.id);
      } else {
        otherTab.classes.remove(_activeClass);
      }
    }
  }
}
