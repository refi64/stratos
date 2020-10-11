/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

import 'package:stratos/drizzle/application.dart';
import 'package:stratos/drizzle/attributes.dart';
import 'package:stratos/drizzle/controller.dart';
import 'package:stratos/inject/captures_interceptor.dart';
import 'package:stratos/inject/controllers/inject.dart';
import 'package:stratos/log.dart';
import 'package:stratos/message.dart';

void attach(ControllerFactory<InjectController> injectFactory) {
  document.body.setAttribute(DZ_CONTROLLER, injectFactory.name);
  Application.register(injectFactory);
  Application.attach();
}

void actualMain() {
  var pipe = ClientSideMessagePipe(
      WindowMessagePipeDelegate(side: MessageSide.client));
  var firstCaptureSet = true;

  CapturesInterceptor()
      .install()
      .transform(streamHandleErrorsTransformer('Capturing requests'))
      .listen((captures) => handleErrors('Sending captures to host', () {
            pipe.outgoing.add(ClientToHostMessage.latestCaptures(captures,
                fromScratch: firstCaptureSet));
            firstCaptureSet = false;
          }));

  var injectFactory = InjectController.createFactory(pipe);

  if (document.readyState == 'complete') {
    attach(injectFactory);
  } else {
    window.onLoad.listen((event) => attach(injectFactory));
  }
}

void main() => mainWrapper(actualMain);
