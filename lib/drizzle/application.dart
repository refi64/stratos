/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

import 'package:js/js_util.dart';
import 'package:stratos/drizzle/attributes.dart';
import 'package:stratos/drizzle/controller.dart';
import 'package:stratos/log.dart';

/// A scoped collection of controller names that can be attached. Note that this
/// is really just a hack for template controllers to work.
class Context {
  final _factories = <String, ControllerFactory>{};
  final Context parent;

  Context._([this.parent]);
  Context() : this._();
  Context.from(Context parent) : this._(parent);

  /// Registers a new controller factory.
  void register(ControllerFactory zFactory) {
    _factories[zFactory.name] = zFactory;
  }

  /// Finds a controller factory by [name], scanning parent contexts if needed.
  ControllerFactory find(String name) => _factories[name] ?? parent?.find(name);
}

/// Finds all elements inside [root]'s DOM tree with the given attribute set,
/// including [root] itself.
List<Element> _findWithAttribute(Element root, String attr) => [
      if (root.hasAttribute(attr)) root,
      ...root.querySelectorAll('[$attr]'),
    ];

/// The centralized "singleton" used to register and attach controllers.
class Application {
  Application._();

  /// The global, shared context.
  static final context = Context();

  /// Registers a new controller factory.
  static void register(ControllerFactory zFactory) {
    context.register(zFactory);
  }

  /// Detaches the controller from the given element, if one is set.
  static void detach(Element element) {
    if (getProperty(element, DZ_CONTROLLER_PROPERTY) != null) {
      var controller = Controller.ofElement(element);
      setProperty(element, DZ_CONTROLLER_PROPERTY, null);
      controller.detach();
    }
  }

  /// Attaches all controllers and actions below [root], looking up controllers
  /// in the given [context]. If [root] is null, it defaults to `document.body`;
  /// [context] defaults to [Application.context].
  static void attach([Element root, Context context]) {
    // XXX: this function is ugly!
    root ??= document.body;
    context ??= Application.context;

    var toMarkReady = <Controller>[];

    // Attach the controllers.
    for (var element in _findWithAttribute(root, DZ_CONTROLLER)) {
      var name = element.getAttribute(DZ_CONTROLLER);
      var controller = context.find(name)?.create();
      if (controller == null) {
        throw ArgumentError.value(name, DZ_CONTROLLER);
      }

      detach(element);
      controller.attach(element);
      // Store the controller on the element for easy lookup later on.
      setProperty(element, DZ_CONTROLLER_PROPERTY, controller);
      toMarkReady.add(controller);
    }

    // Attach the attributes.
    for (var element in _findWithAttribute(root, DZ_ACTIONS)) {
      var actions = element.getAttribute(DZ_ACTIONS).split(';');
      for (var spec in actions) {
        var parts = spec.split(':');
        if (parts.length != 2 && parts.length != 3) {
          throw ArgumentError.value(spec, DZ_ACTIONS);
        }

        var eventName = parts[0];
        var controllerName = parts[1];
        var actionName = parts.length == 3 ? parts[2] : eventName;

        var controller = findParentControllerByName(element, controllerName);
        if (controller == null) {
          throw ArgumentError.value(spec, DZ_ACTIONS);
        }

        var action = controller.actions[actionName];
        if (action == null) {
          throw ArgumentError.value(spec, DZ_ACTIONS);
        }

        // XXX: What if the action throws an error? This needs better handling.
        if (actionName == 'attach') {
          action(element, null);
        } else {
          element.addEventListener(
              eventName,
              (event) => mainWrapper(() => handleErrorsMaybeAsync(
                  'Running listener for $eventName',
                  () => action(element, event))));
        }
      }
    }

    // XXX: This is very similar to the actions code above.
    for (var element in _findWithAttribute(root, DZ_CONTENT)) {
      var targets = element.getAttribute(DZ_CONTENT).split(';');
      for (var spec in targets) {
        var parts = spec.split(':');
        if (parts.length != 2 && parts.length != 3) {
          throw ArgumentError.value(spec, DZ_CONTENT);
        }

        String target, controllerName, subjectName;
        if (parts.length == 3) {
          target = parts[0];
          controllerName = parts[1];
          subjectName = parts[2];
        } else {
          controllerName = parts[0];
          subjectName = parts[1];
        }

        var controller = findParentControllerByName(element, controllerName);
        if (controller == null) {
          throw ArgumentError.value(spec, DZ_CONTENT);
        }

        var subject = controller.contentSubjects[subjectName];
        if (subject == null) {
          throw ArgumentError.value(spec, DZ_CONTENT);
        }

        subject.listen((value) {
          if (target == null) {
            element.innerText = value;
          } else {
            element.setAttribute(target, value);
          }
        });
      }
    }

    for (var controller in toMarkReady) {
      controller.onReady();
    }
  }
}
