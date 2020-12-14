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

/// A single item formatted as target:controller:value, which may appear in a
/// semicolon-separated line in attributes like dz-actions.
class Spec {
  final String target;
  final String controller;
  final String value;

  Spec({this.target, this.controller, this.value});

  static List<Spec> parseLine(String line, String argument) =>
      line.split(';').map((s) => parse(s, argument)).toList();

  static Spec parse(String spec, String argument) {
    var parts = spec.split(':');
    if (parts.length != 2 && parts.length != 3) {
      throw ArgumentError.value(spec, argument);
    }

    return Spec(
        target: parts[0],
        controller: parts[1],
        value: parts.length == 3 ? parts[2] : parts[0]);
  }

  @override
  String toString() => '$target:$controller:$value';
}

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
      var actions = element.getAttribute(DZ_ACTIONS);
      for (var spec in Spec.parseLine(actions, DZ_ACTIONS)) {
        var controller = findParentControllerByName(element, spec.controller);
        if (controller == null) {
          throw ArgumentError.value(spec, DZ_ACTIONS);
        }

        var action = controller.actions[spec.value];
        if (action == null) {
          throw ArgumentError.value(spec, DZ_ACTIONS);
        }

        // XXX: What if the action throws an error? This needs better handling.
        if (spec.value == 'attach') {
          action(element, null);
        } else {
          var listener = (Event event) => mainWrapper(() =>
              handleErrorsMaybeAsync('Running listener for ${spec.target}',
                  () => action(element, event)));

          element.addEventListener(spec.target, listener);
          element.addEventListener('drizzle:${spec.target}',
              (event) => listener((event as CustomEvent).detail as Event));
        }
      }
    }

    // XXX: This is very similar to the actions code above.
    for (var element in _findWithAttribute(root, DZ_CONTENT)) {
      var targets = element.getAttribute(DZ_CONTENT);
      for (var spec in Spec.parseLine(targets, DZ_CONTENT)) {
        var controller = findParentControllerByName(element, spec.controller);
        if (controller == null) {
          throw ArgumentError.value(spec, DZ_CONTENT);
        }

        var subject = controller.contentSubjects[spec.value];
        if (subject == null) {
          throw ArgumentError.value(spec, DZ_CONTENT);
        }

        subject.listen((value) {
          if (spec.target == r'$text') {
            element.innerText = value;
          } else {
            element.setAttribute(spec.target, value);
          }
        });
      }
    }

    for (var controller in toMarkReady) {
      controller.onReady();
    }
  }
}
