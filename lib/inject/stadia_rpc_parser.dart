/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:convert';

import 'package:meta/meta.dart';

class ResponseParseException implements Exception {
  final String message;
  ResponseParseException(this.message);
  @override
  String toString() => 'Failed to parse response: $message';
}

/// This parses a Stadia server response [data] (from the `batchexecute`
/// endpoint) and looks for a response to [id]. If found, the data is returned,
/// otherwise `null` is returned.
dynamic parseBatchResponse({@required String id, @required String data}) {
  // The format looks a bit like:
  // 12345 [["a", ...
  // ]
  // The first part is *supposed* to be a length, but...it's not always correct
  // for some reason. Therefore, it's easiest to just look for the closing ]
  // on its own line and use that to determine where the JSON starts & ends.
  // A single request to batchexecute may contain *multiple* RPC method calls,
  // so they must be walked through to find the desired one.
  var i = 0;
  while (true) {
    final responseStart = data.indexOf('[', i);
    if (responseStart == -1) {
      break;
    }

    final responseEnd = data.indexOf('\n]\n', responseStart);
    if (responseEnd == -1) {
      throw ResponseParseException('Unterminated response block');
    }

    // + 2 is to make sure the terminating ] is included.
    var response =
        jsonDecode(data.substring(responseStart, responseEnd + 2)) as List;
    if (response[0][1] == id) {
      return jsonDecode(response[0][2] as String);
    }

    i = responseEnd + 1;
  }
}
