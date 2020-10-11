/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// Bindings to some chrome.tabs APIs.
@JS('chrome.tabs')
library stratos.chrome.tabs;

import 'package:js/js.dart';

const tabIdNone = -1;

@JS()
@anonymous
class Tab {
  external int get id;
  external String get url;
}

@JS()
@anonymous
class _CreateOptions {
  external String get url;
  external bool get active;

  external factory _CreateOptions({String url, bool active});
}

@JS('create')
external void _create(_CreateOptions options);

void create({String url, bool active}) =>
    _create(_CreateOptions(url: url, active: active));
