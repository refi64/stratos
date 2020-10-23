import 'dart:async';
import 'dart:html';

import 'package:stratos/drizzle/controller.dart';
import 'package:stratos/inject/controllers/captures.dart';
import 'package:stratos/log.dart';
import 'package:stratos/message.dart';

/// A Drizzle controller that attaches to the root body and determines if we're
/// on the captures page to load / unload the [CapturesController].
class PageController extends Controller {
  static const factoryName = 'page';
  static ControllerFactory<PageController> createFactory(
          ClientSideMessagePipe pipe) =>
      ControllerFactory(factoryName, () => PageController._(pipe));

  static const _capturesPath = '/captures';

  final ClientSideMessagePipe pipe;
  StreamSubscription _messageSubscription;

  MutationObserver _rootObserver;
  MutationObserver _childrenObserver;

  CapturesController _capturesController;

  final _currentStatuses = <String, CaptureSyncStatus>{};
  var _syncAvailable = true;

  PageController._(this.pipe) {
    _messageSubscription = pipe.onMessage.listen(_handleMessage);
  }

  @override
  void onAttach() {
    _rootObserver = MutationObserver(_onRouterMutations);
    _childrenObserver = MutationObserver(_onChildrenStyleMutations);

    // This is the root view where routes on the Stadia page are added to.
    var routerView = element.querySelector('[role=main]');
    _rootObserver.observe(routerView, childList: true);

    element.children.forEach(_watchNewChild);

    if (window.location.pathname == _capturesPath) {
      // Attach to the root of the captures view area.
      var capturesView = element.querySelector('.neTWrf');

      CapturesController.factory.instantiate(capturesView);
      _capturesController =
          Controller.ofElement<Element, CapturesController>(capturesView);

      _capturesController.captureStatuses.add(_currentStatuses);
      _capturesController.syncAvailability.add(_syncAvailable);
    }
  }

  @override
  void onDetach() {
    _capturesController?.detach();

    _rootObserver.disconnect();
    _childrenObserver.disconnect();

    _messageSubscription.cancel();
  }

  /// Updates the current controller state depending on whether or not we're
  /// on the captures page.
  void _checkPage() {
    if (window.location.pathname == _capturesPath) {
      if (_capturesController == null) {
        // We just moved to the captures page.
        window.location.reload();
      }
    } else if (_capturesController != null) {
      logger.d('Left captures page for ${window.location.pathname}');
      _capturesController.detach();
      _capturesController = null;
    }
  }

  void _handleMessage(HostToClientMessage message) {
    message.when(syncAvailability: (syncAvailable) {
      _syncAvailable = syncAvailable;
      _capturesController?.syncAvailability?.add(syncAvailable);
    }, updateCaptureStatuses: (captureStatuses) {
      _currentStatuses.addAll(captureStatuses);
      _capturesController?.captureStatuses?.add(captureStatuses);
    });
  }

  /// Called when new nodes are added to the view where page routes are rendered
  /// to. This generally means that a new page was just entered.
  void _onRouterMutations(List<dynamic> mutations, MutationObserver _) {
    for (var mutation in mutations.cast<MutationRecord>()) {
      assert(mutation.type == 'childList');
      mutation.addedNodes.whereType<Element>().forEach(_watchNewChild);
    }

    _checkPage();
  }

  /// Called when the styles of a child of the router view are modified. This
  /// generally means that the visibility of a previous-rendered route was
  /// changed, which would imply the use of back/forward navigation.
  void _onChildrenStyleMutations(List<dynamic> mutations, MutationObserver _) {
    _checkPage();
  }

  void _watchNewChild(Element child) {
    _childrenObserver
        .observe(child, attributes: true, attributeFilter: ['style']);
  }
}
