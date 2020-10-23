/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

import 'package:js/js_util.dart';
import 'package:rxdart/rxdart.dart';

import 'application.dart';
import 'attributes.dart';

/// The type of a controller action.
typedef Action = void Function(Element target, Event event);

abstract class Controller<E extends Element> {
  /// Finds and returns the controller instance on an element, or null if there
  /// is none attached. Will throw an exception if the controller type is not
  /// valid.
  static C ofElement<E extends Element, C extends Controller<E>>(E element) =>
      getProperty(element, DZ_CONTROLLER_PROPERTY) as C;

  /// Called on attach.
  void onAttach() {}

  /// Called on ready.
  void onReady() {}

  /// Called on detach.
  void onDetach() {}

  /// Installs [newActions] as actions on this controller.
  void installActions(Map<String, Action> newActions) {
    _actions.addAll(newActions);
  }

  /// Acquires a new [BehaviorSubject] attached to this controller. [seed]
  /// is used as an initial seed value for the subject, if given.
  BehaviorSubject<String> acquireContentSubject(String name, {String seed}) {
    var subject =
        seed != null ? BehaviorSubject.seeded(seed) : BehaviorSubject<String>();
    _contentSubjects[name] = subject;
    return subject;
  }

  /// Attaches to the given element. Do not call directly; use
  /// [Application.attach] instead.
  void attach(E element) {
    this.element = element;
    onAttach();
  }

  /// Detaches from the given element. Do not call directly; use
  /// [Application.detach] instead.
  void detach() {
    onDetach();
    element = null;
    _contentSubjects.values.forEach((subject) => subject.close());
  }

  /// Finds a parent controller created from [factory].
  C findParentByFactory<C extends Controller>(ControllerFactory<C> factory) =>
      findParentControllerByFactory(element, factory);

  /// Finds a parent controller with the given [name].
  C findParentByName<C extends Controller>(String name) =>
      findParentControllerByName(element, name);

  /// The element currently attached to, or `null` if not attached yet.
  E element;

  Map<String, Action> get actions => Map.unmodifiable(_actions);
  final _actions = <String, Action>{};

  Map<String, BehaviorSubject<String>> get contentSubjects =>
      Map.unmodifiable(_contentSubjects);
  final _contentSubjects = <String, BehaviorSubject<String>>{};
}

/// Finds a parent controller of the given [element] created from [factory].
C findParentControllerByFactory<E extends Element, C extends Controller<E>>(
        Element element, ControllerFactory<C> factory) =>
    findParentControllerByName(element, factory.name);

/// Finds a parent controller of the given [element] with the given [name].
C findParentControllerByName<E extends Element, C extends Controller<E>>(
    Element element, String name) {
  var controllerElement = element.closest('[$DZ_CONTROLLER=$name]');
  if (controllerElement == null) {
    return null;
  }

  return Controller.ofElement(controllerElement);
}

/// A factory that can create a controller.
class ControllerFactory<C extends Controller> {
  final String name;
  final C Function() _factoryFunction;

  ControllerFactory(this.name, this._factoryFunction);

  /// Creates the controller.
  Controller create() => _factoryFunction();

  void instantiate(Element target) {
    target.setAttribute(DZ_CONTROLLER, name);
    var context = Context.from(Application.context)..register(this);
    Application.attach(target, context);
  }
}
