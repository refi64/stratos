import 'dart:async';
import 'dart:html';

import 'package:rxdart/rxdart.dart';
import 'package:stratos/drizzle/template.dart';
import 'package:stratos/drizzle/utils.dart';
import 'package:stratos/cancellable_pipe.dart';
import 'package:stratos/message.dart';

import 'inject.dart';
import 'status_icon.dart';

class HeaderController extends TemplateController {
  @override
  String get template => 'header';

  final _subscriptionsToCancel = <StreamSubscription>[];

  /// A subject for the current status text.
  BehaviorSubject<String> _textSubject;

  /// The stream of new statuses.
  final _statusSubject = BehaviorSubject<SyncStatus>.seeded(null);

  /// A sink for adding new statuses.
  StreamSink<SyncStatus> get statuses => _statusSubject.sink;

  /// The stream of the sync availability.
  final _syncAvailabilitySubject = BehaviorSubject<bool>.seeded(true);

  /// A sink for updating the sync availability.
  StreamSink<bool> get syncAvailability => _syncAvailabilitySubject.sink;

  /// The status icon controller.
  final _statusIconController =
      StatusIconController(id: StatusIconController.idSyncAll);

  Element _signInLink;

  HeaderController() {
    _textSubject = acquireContentSubject('statusText');
    installActions({'auth': _requestAuth});
  }

  @override
  void onAttach() {
    _signInLink = element.querySelector('.stratos-header-sign-in');
    _signInLink.hide();

    _statusIconController.instantiateInto(element);

    _subscriptionsToCancel.add(
        _statusSubject.stream.cancellablePipe(_statusIconController.statuses));
    _subscriptionsToCancel.add(_syncAvailabilitySubject.stream
        .cancellablePipe(_statusIconController.syncAvailability));

    _subscriptionsToCancel.add(_statusSubject.stream.listen(_updateStatus));
    _subscriptionsToCancel
        .add(_syncAvailabilitySubject.stream.listen(_updateAvailability));
  }

  @override
  void onDetach() {
    _subscriptionsToCancel.forEach((sub) => sub.cancel());
  }

  void _requestAuth(Element target, Event event) {
    var inject =
        findParentByName<InjectController>(InjectController.factoryName);
    inject.pipe.outgoing.add(ClientToHostMessage.requestAuth());
    event.preventDefault();
  }

  void _updateAvailability(bool available) {
    if (!available) {
      _signInLink.show();
      _textSubject.add('');
    }
  }

  void _updateStatus(SyncStatus status) {
    if (status == null) {
      _textSubject.add('Checking capture statuses...');
    } else {
      _textSubject.add('');
    }
  }
}
