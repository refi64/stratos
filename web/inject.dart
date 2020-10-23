/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

import 'package:stratos/inject/captures_interceptor.dart';
import 'package:stratos/inject/controllers/page.dart';
import 'package:stratos/log.dart';
import 'package:stratos/message.dart';

void actualMain() {
  var pipe = ClientSideMessagePipe(WindowClientMessagePipeDelegate());
  var firstCaptureSet = true;

  CapturesInterceptor()
      .install()
      .transform(streamHandleErrorsTransformer('Capturing requests'))
      .listen((captures) => handleErrors('Sending captures to host', () {
            pipe.outgoing.add(ClientToHostMessage.latestCaptures(captures,
                fromScratch: firstCaptureSet));
            firstCaptureSet = false;
          }));

  var pageFactory = PageController.createFactory(pipe);

  if (document.readyState == 'complete') {
    pageFactory.instantiate(document.body);
  } else {
    window.onLoad.listen((event) => pageFactory.instantiate(document.body));
  }
}

void main() => mainWrapper(actualMain);
