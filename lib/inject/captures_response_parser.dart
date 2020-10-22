/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

library stratos.inject.response;

import 'package:stratos/capture.dart';
import 'package:stratos/log.dart';

class ResponseParseException implements Exception {
  final String message;
  ResponseParseException(this.message);
  @override
  String toString() => 'Failed to parse response: $message';
}

/// Parses the result of a request to the captures list API.
CaptureSet parseCapturesResponse(dynamic response) {
  final millisecondsPerSecond = 1000;
  var capturesById = <String, Capture>{};

  for (var data in response[0]) {
    logger.d('DATA: $data');

    var id = data[1] as String;
    var game = data[3] as String;
    var creation = DateTime.fromMillisecondsSinceEpoch(
        (data[4] as List).cast<int>().first * millisecondsPerSecond);

    Size size;
    String image, url;

    // If data[7] is null, it's a video with the data in data[8], otherwise it's
    // a still image.
    if (data[7] == null) {
      size = Size(width: data[8][3][1] as int, height: data[8][3][2] as int);
      image = data[8][0][0] as String;
      url = data[8][1] as String;
    } else {
      // Photo.
      size = Size(width: data[7][0][1] as int, height: data[7][0][2] as int);
      image = data[7][0][0] as String;
      url = data[7][1] as String;
    }

    capturesById[id] = Capture(
        id: id,
        game: game,
        size: size,
        url: url,
        image: image,
        creation: creation);
  }

  return CaptureSet(capturesById);
}
