/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

import 'package:stratos/chrome/runtime.dart' as chrome_runtime;
import 'package:stratos/log.dart';
import 'package:stratos/message.dart';

void actualMain() {
  var el = ScriptElement();
  el.src = chrome_runtime.getURL('inject.dart.js');
  document.documentElement.append(el);

  // Pretend we are the host to bridge the messages, so the injected script can
  // talk to the host side.
  var clientPipeDelegate = WindowMessagePipeDelegate(side: MessageSide.host);
  var hostPipeDelegate = PortMessagePipeDelegate.connect();

  MessagePipeBridge(clientPipeDelegate, hostPipeDelegate).forwardAll();
}

void main() => mainWrapper(actualMain);
