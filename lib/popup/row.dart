/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stratos/cancellable_pipe.dart';
import 'package:stratos/capture.dart';
import 'package:stratos/drizzle/template.dart';
import 'package:stratos/drizzle/utils.dart';

/// A Drizzle controller attached to an individual capture row.
class RowController extends TemplateController {
  final Capture capture;

  final _percentSubject = BehaviorSubject<double>.seeded(null);
  StreamSink<double> get percent => _percentSubject.sink;

  BehaviorSubject<String> _formattedPercentSubject;
  StreamSubscription _pipeSubscription;

  RowController(this.capture) {
    acquireContentSubject('thumbnail', seed: capture.thumbnail);
    acquireContentSubject('game', seed: capture.game);
    acquireContentSubject('date',
        seed: DateFormat('yyyy-MM-dd hh:mm a').format(capture.creation));

    // Format the percentage to go into the element.
    _formattedPercentSubject = acquireContentSubject('percent', seed: null);

    _pipeSubscription = _percentSubject.stream
        .where((percent) => percent != null)
        .map((percent) => '${(percent * 100).truncate()}%')
        .cancellablePipe(_formattedPercentSubject.sink);
  }

  @override
  void onAttach() {
    _percentSubject.stream.listen((percent) {
      var percentElement = element.querySelector('.progress-row-percent');
      if (percent != null) {
        percentElement.show();
      } else {
        percentElement.hide();
      }
    });
  }

  @override
  void onDetach() {
    _pipeSubscription.cancel();
    _percentSubject.close();
  }

  @override
  String get template => 'row';
}
