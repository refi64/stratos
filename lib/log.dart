/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// Contains a global logger and various error-trapping routines.
@JS()
library stratos.log;

import 'dart:async';
import 'dart:html';

import 'package:js/js.dart';
import 'package:logger/logger.dart';
import 'package:stack_trace/stack_trace.dart';

/// A [LogPrinter] that uses [Chain]s over plain [StackTrace]s and adds a custom
/// prefix.
class _StratosPrettyPrinter extends LogPrinter {
  final PrettyPrinter _prettyPrinter;
  _StratosPrettyPrinter(this._prettyPrinter);

  @override
  List<String> log(LogEvent event) => _prettyPrinter.log(LogEvent(
      event.level,
      '[Stratos] ${event.message}',
      event.error,
      event.stackTrace != null
          ? Chain.forTrace(event.stackTrace).terse
          : null));
}

/// A [LogOutput] that prints to the browser console.
class _ConsoleLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    var message = event.lines.join('\n');
    switch (event.level) {
      case Level.nothing:
        break;
      case Level.verbose:
      case Level.debug:
        window.console.debug(message);
        break;
      case Level.info:
        window.console.info(message);
        break;
      case Level.warning:
        window.console.warn(message);
        break;
      case Level.error:
      case Level.wtf:
        window.console.error(message);
        break;
    }
  }
}

final logger = Logger(
    filter: ProductionFilter(),
    printer: _StratosPrettyPrinter(
        PrettyPrinter(colors: false, methodCount: 999, errorMethodCount: 999)),
    output: _ConsoleLogOutput(),
    level: Level.debug);

void _logError(String context, dynamic err, [StackTrace stackTrace]) {
  logger.e(context, err, stackTrace);
}

/// Calls the given [func], logging any errors occurring during execution. If
/// the function is async, use [handleErrorsMaybeAsync] instead.
void handleErrors(String context, void Function() func) {
  try {
    func();
  } catch (ex) {
    _logError(context, ex, ex is Error ? ex.stackTrace : null);
  }
}

/// Calls the given [func], await-ing its result in case it was async.
void handleErrorsMaybeAsync(String context, dynamic Function() func) async {
  try {
    await func();
  } catch (ex) {
    _logError(context, ex, ex is Error ? ex.stackTrace : null);
  }
}

/// Returns a stream transformer that handles any errors that have occurred.
/// XXX: I really need to use this way more often...
StreamTransformer<T, T> streamHandleErrorsTransformer<T>(String context) =>
    StreamTransformer<T, T>.fromHandlers(
        handleError: (err, trace, sink) => _logError(context, err, trace));

/// Wraps a main function, adding [Chain] support.
void mainWrapper(void Function() func) => Chain.capture(func,
    onError: (err, chain) => _logError('In main', err, chain));
