/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

library stratos.capture;

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'capture.g.dart';

/// The size of a capture.
/// XXX: Why tf is this even here, we never use the size. :/
@JsonSerializable()
class Size {
  final int width, height;
  Size({this.width, this.height});

  factory Size.fromJson(Map<String, dynamic> data) => _$SizeFromJson(data);
  Map<String, dynamic> toJson() => _$SizeToJson(this);

  @override
  String toString() => '[${width}x${height}]';
}

/// A capture that can be synced.
@JsonSerializable()
class Capture {
  final Size size;

  /// The ID.
  final String id;

  /// The game this capture is from.
  final String game;

  /// The URL that can be used to download the capture.
  final String url;

  /// An image that can be used to preview the capture.
  final String image;

  /// The creation time.
  final DateTime creation;

  Capture(
      {@required this.id,
      @required this.size,
      @required this.game,
      @required this.url,
      @required this.image,
      @required this.creation});

  factory Capture.fromJson(Map<String, dynamic> data) =>
      _$CaptureFromJson(data);
  Map<String, dynamic> toJson() => _$CaptureToJson(this);

  // NOTE: these sizes are hardcoded in popup.css as well.
  String get thumbnail => '$image=w160-h90-rw-no';

  @override
  String toString() => 'Capture[$id; $size; $game; $url; $creation]';
}

/// A set of [Capture] instances.
/// XXX: This should be removed, it only existed for a short period of time
/// where the capture list was sent over the message pipe directly.
@JsonSerializable()
class CaptureSet {
  final Map<String, Capture> capturesById;
  CaptureSet([this.capturesById = const <String, Capture>{}]);

  factory CaptureSet.fromJson(Map<String, dynamic> data) =>
      _$CaptureSetFromJson(data);
  Map<String, dynamic> toJson() => _$CaptureSetToJson(this);
}
