/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:async';

extension CancellablePipe<T> on Stream<T> {
  /// Pipe this stream into the given [sink], and returns a subscription that
  /// can be cancelled. This is similar to [Stream.pipe], but that one is not
  /// cancellable without closing the source stream.
  StreamSubscription cancellablePipe(Sink<T> sink) => listen(sink.add);
}
