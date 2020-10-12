/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'package:stratos/background/auth.dart';
import 'package:stratos/message.dart';
import 'package:stratos/background/handler.dart';
import 'package:stratos/log.dart';
import 'package:stratos/chrome/runtime.dart' as chrome_runtime;

void actualMain() {
  var authService = AuthService();
  var handler = MessageHandler(authService);

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

    var authSub = authService.hasAuth.listen((hasAuth) {
      pipe.outgoing.add(HostToClientMessage.syncAvailability(hasAuth));
    });

    // Make sure the new client has all the updated statuses and sync
    // availability.
    // XXX: right now this sends the updated statuses to *all* clients. Really,
    // it should only be sending them to the new one...
    authService.sendAuthStatus();
    handler.sendCurrentStatuses();

    port.onDisconnect.then((void _) {
      authSub.cancel();
      sendSub.cancel();
    });
  });
}

void main() => mainWrapper(actualMain);
