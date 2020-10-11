/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'package:stratos/auth.dart';
import 'package:stratos/message.dart';
import 'package:stratos/background/handler.dart';
import 'package:stratos/log.dart';
import 'package:stratos/chrome/runtime.dart' as chrome_runtime;

void actualMain() {
  var handler = MessageHandler();

  chrome_runtime.onConnect.listen((port) {
    if (port.name != messagePort) {
      logger.w('Unexpected message port ${port.name}');
      return;
    }

    // Note that this uses a new message pipe for every individual client.
    var pipe = HostSideMessagePipe(PortMessagePipeDelegate(port));
    pipe.onMessage.forEach((message) => handleErrorsMaybeAsync(
        'Handling message', () => handler.handle(message)));

    var sendSub =
        handler.outgoing.listen((message) => pipe.outgoing.add(message));

    var authSub = watchNeedsReauth().listen((needsReauth) {
      pipe.outgoing.add(HostToClientMessage.syncAvailability(!needsReauth));
    });

    // Make sure the new client has all the updated statuses.
    // XXX: right now this sends the updated statuses to *all* clients. Really,
    // it should only be sending them to the new one...
    handler.sendCurrentStatuses();

    port.onDisconnect.then((void _) {
      authSub.cancel();
      sendSub.cancel();
    });
  });
}

void main() => mainWrapper(actualMain);
