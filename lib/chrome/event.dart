/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

@JS()
library stratos.chrome.listener;

import 'dart:async';

import 'package:js/js.dart';

/// A Chrome extension API listenable event.
@JS()
@anonymous
class Event {
  external void addListener(dynamic callback);
  external void removeListener(dynamic callback);
}

/// Creates a new broadcast `StreamController` that is tied to the given
/// [event]'s lifetime. [callback] will be called on each event and should
/// add some event data to the new controller.
StreamController<T> createEventStreamController<T>(
        Event event, Function callback) =>
    StreamController<T>.broadcast(
        onListen: () => event.addListener(callback),
        onCancel: () => event.removeListener(callback));
