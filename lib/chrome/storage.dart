/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// Bindings to some chrome.storage APIs.
@JS('chrome.storage')
library stratos.chrome.storage;

import 'dart:async';
import 'dart:html_common';

import 'package:js/js.dart';
import 'package:js/js_util.dart';

import 'event.dart';

@JS('Object.keys')
external List<String> _objectKeys(dynamic object);

@JS()
@anonymous
class _JsStorageArea {
  external void get(dynamic keys, Function callback);
  external void set(dynamic items, Function callback);
  external void remove(dynamic keys, Function callback);
  external void clear(Function callback);
}

class StorageArea {
  StorageArea._(this._js);

  final _JsStorageArea _js;

  Future<String> get(String key) {
    final completer = Completer<String>();
    _js.get(
        key,
        allowInterop((dynamic items) =>
            completer.complete(getProperty(items, key) as String)));
    return completer.future;
  }

  Future<void> put(String key, String value) {
    final completer = Completer<void>();
    _js.set(convertDartToNative_Dictionary(<String, String>{key: value}),
        allowInterop(() => completer.complete()));
    return completer.future;
  }

  Future<void> remove(String key) {
    final completer = Completer<void>();
    _js.remove(key, allowInterop(() => completer.complete()));
    return completer.future;
  }

  Future<void> clear() {
    final completer = Completer<void>();
    _js.clear(allowInterop(() => completer.complete()));
    return completer.future;
  }
}

@JS('sync')
external _JsStorageArea get _jsSync;
@JS('local')
external _JsStorageArea get _jsLocal;

StorageArea get sync => StorageArea._(_jsSync);
StorageArea get local => StorageArea._(_jsLocal);

@JS()
@anonymous
class StorageChange {
  external String get oldValue;
  external String get newValue;
}

class OnChangedEvent {
  final Map<String, StorageChange> changes;
  final String namespace;

  OnChangedEvent(this.changes, this.namespace);
}

@JS('onChanged')
external Event get _onChanged;

final _onChangedController =
    createEventStreamController<OnChangedEvent>(_onChanged, _onChangedCallback);

final Function _onChangedCallback =
    allowInterop((dynamic jsChanges, String namespace) {
  var changes = {
    for (var key in _objectKeys(jsChanges))
      key: getProperty(jsChanges, key) as StorageChange
  };
  _onChangedController.add(OnChangedEvent(changes, namespace));
});

Stream<OnChangedEvent> get onChanged => _onChangedController.stream;
