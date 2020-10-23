import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stratos/drizzle/template.dart';
import 'package:stratos/drizzle/utils.dart';
import 'package:stratos/cancellable_pipe.dart';
import 'package:stratos/message.dart';

import 'page.dart';
import 'status_icon.dart';

class CaptureStatusCheckProgress {
  final int checked;
  final int total;

  CaptureStatusCheckProgress({@required this.checked, @required this.total});
}

class HeaderController extends TemplateController {
  @override
  String get template => 'header';

  final _subscriptionsToCancel = <StreamSubscription>[];

  /// A subject for the number of currently checked items.
  BehaviorSubject<String> _checkedSubject;

  /// A subject for the total number of items to check.
  BehaviorSubject<String> _totalToCheckSubject;

  /// The stream of new statuses.
  final _statusSubject = BehaviorSubject<SyncStatus>.seeded(null);

  /// A sink for adding new statuses. `null`
  StreamSink<SyncStatus> get statuses => _statusSubject.sink;

  /// The stream of the sync availability.
  final _syncAvailabilitySubject = BehaviorSubject<bool>.seeded(true);

  /// A sink for updating the sync availability.
  StreamSink<bool> get syncAvailability => _syncAvailabilitySubject.sink;

  /// The stream for the current check progress information.
  final _checkProgressController =
      StreamController<CaptureStatusCheckProgress>();

  /// A sink for updating the check progress information.
  StreamSink<CaptureStatusCheckProgress> get checkProgress =>
      _checkProgressController.sink;

  /// The status icon controller.
  final _statusIconController =
      StatusIconController(id: StatusIconController.idSyncAll);

  Element _signInLink;
  Element _checkProgress;

  HeaderController() {
    _checkedSubject = acquireContentSubject('checked');
    _totalToCheckSubject = acquireContentSubject('totalToCheck');

    installActions({'auth': _requestAuth});

    _subscriptionsToCancel
        .add(_checkProgressController.stream.listen((progress) {
      _checkedSubject.add(progress.checked.toString());
      _totalToCheckSubject.add(progress.total.toString());
    }));
  }

  @override
  void onAttach() {
    _signInLink = element.querySelector('.stratos-header-sign-in');
    _signInLink.hide();

    _checkProgress = element.querySelector('.stratos-header-check');

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
    var controller =
        findParentByName<PageController>(PageController.factoryName);
    controller.pipe.outgoing.add(ClientToHostMessage.requestAuth());
    event.preventDefault();
  }

  void _updateAvailability(bool available) {
    if (!available) {
      _signInLink.show();
      _checkProgress.hide();
    }
  }

  void _updateStatus(SyncStatus status) {
    if (status == null) {
      _checkProgress.show();
    } else {
      _checkProgress.hide();
    }
  }
}
