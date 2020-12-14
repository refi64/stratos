/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

import 'package:stratos/chrome/runtime.dart' as chrome_runtime;
import 'package:stratos/drizzle/application.dart';
import 'package:stratos/drizzle/attributes.dart';
import 'package:stratos/log.dart';
import 'package:stratos/message.dart';

Iterable<Element> querySelectorOnSelfAndParents(
    Element element, String selector) sync* {
  while (true) {
    var match = element.closest(selector);
    if (match == null) {
      break;
    }

    yield match;
    element = match.parent;
  }
}

bool testActionsAndDispatch(Element el, String eventName, Event event) {
  var actions = el.getAttribute(DZ_ACTIONS);
  if (Spec.parseLine(actions, DZ_ACTIONS)
      .any((spec) => spec.target == eventName)) {
    event.stopImmediatePropagation();

    var drizzleEvent = 'drizzle:$eventName';
    el.dispatchEvent(CustomEvent(drizzleEvent, detail: event));

    return true;
  }

  return false;
}

void interceptWizEventsForDrizzle() {
  final eventName = 'click';

  window.addEventListener(eventName, (baseEvent) {
    var event = baseEvent as MouseEvent;
    var target = document.elementFromPoint(
        event.client.x.floor(), event.client.y.floor());

    for (var el in target.querySelectorAll('[$DZ_ACTIONS]')) {
      if (target.contains(el) &&
          el.getBoundingClientRect().containsPoint(event.client)) {
        target = el;
      }
    }

    for (var el in querySelectorOnSelfAndParents(target, '[$DZ_ACTIONS]')) {
      if (testActionsAndDispatch(el, eventName, event)) {
        break;
      }
    }
  }, true);
}

void actualMain() {
  interceptWizEventsForDrizzle();

  var hostPipeDelegate = PortMessagePipeDelegate.connect();
  var clientPipeDelegate = WindowHostMessagePipeDelegate();
  var bridge = MessagePipeBridge(clientPipeDelegate, hostPipeDelegate);

  // Don't start forwarding until the client is ready, so we'll stay collecting
  // messages until then.
  clientPipeDelegate.onClientReady.then((_) => bridge.forwardAll());

  var el = ScriptElement();
  el.src = chrome_runtime.getURL('inject.dart.js');
  document.documentElement.append(el);
}

void main() => mainWrapper(actualMain);
