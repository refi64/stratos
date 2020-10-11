/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

extension ElementShowHide on Element {
  /// Sets the display of the element to make it hidden.
  void hide() {
    style.display = 'none';
  }

  /// Undoes [hide].
  void show() {
    style.removeProperty('display');
  }
}
