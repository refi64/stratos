/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

import 'package:stratos/chrome/runtime.dart' as chrome_runtime;
import 'package:stratos/log.dart';
import 'package:stratos/message.dart';

void actualMain() {
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
