/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

library stratos.inject.captures_interceptor;

import 'dart:async';

import 'package:stratos/inject/stadia_rpc_parser.dart';
import 'package:stratos/log.dart';
import 'package:stratos/capture.dart';
import 'package:stratos/inject/captures_response_parser.dart';
import 'package:stratos/inject/xhr.dart';

class CapturesInterceptor {
  // The method ID that returns the captures list.
  static const _rpcQueryId = 'CmnEcf';

  Stream<CaptureSet> install() {
    logger.i('Installing request interceptor');

    return interceptRequests()
        .transform(StreamTransformer<XhrRequest, CaptureSet>.fromHandlers(
      handleData: (XhrRequest req, EventSink<CaptureSet> sink) async {
        var uri = Uri.tryParse(req.url);
        // batchexecute may be passed multiple requests at once, so make sure
        // this one will contain what we want.
        var rpcids = (uri?.queryParameters ?? {})['rpcids'];
        if (rpcids != null && rpcids.split(',').contains(_rpcQueryId)) {
          logger.d('Intercepted captures API request: ${req.url}');
          var responseString = (await req.response()).response as String;

          handleErrors('Error loading response data', () {
            var captures = parseCapturesResponse(
                parseBatchResponse(id: _rpcQueryId, data: responseString));
            sink.add(captures);
          });
        }
      },
    ));
  }
}
