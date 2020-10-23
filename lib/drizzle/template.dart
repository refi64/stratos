/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:html';

import 'package:stratos/drizzle/application.dart';

import 'attributes.dart';
import 'controller.dart';

/// A controller that has a template associated with it.
abstract class TemplateController<E extends Element> extends Controller<E> {
  /// The name of the template. A template element with dz-template set to this
  /// value will be used for instantiation.
  String get template;

  /// Instantiates this template, replacing the element at [location]. Any
  /// previous controllers on the element will be removed.
  void instantiateReplacing(Element location) => _instantiate((clone) {
        Application.detach(location);
        var oldAttrs = <String, String>{};
        if (location.hasAttribute(DZ_PRESERVE)) {
          oldAttrs = location.attributes;
        }
        location.replaceWith(clone);
        // Make sure any new attributes with the same name as old ones will
        // override them.
        oldAttrs.addAll(clone.attributes);
        clone.attributes = oldAttrs;
      });

  /// Instantiates this template, appending its element to the children of given
  /// the given [parent]. If [before] is not null, the template's content will
  /// instead be inserted before [before].
  void instantiateInto(Element parent, {Element before}) =>
      _instantiate((clone) {
        if (before != null) {
          parent.insertBefore(clone, before);
        } else {
          parent.append(clone);
        }
      });

  void _instantiate(void Function(Element clone) inserter) {
    var element = document.querySelector('template[$DZ_TEMPLATE=$template]')
        as TemplateElement;
    var clone = element.content.children.first.clone(true) as Element;
    // This whole thing is a hack: we basically set the attributes as if the
    // controller were globally registered but use a custom context.
    var controllerName =
        element.getAttribute(DZ_TEMPLATE_CONTROLLER) ?? template;
    clone.setAttribute(DZ_CONTROLLER, controllerName);
    var zFactory = ControllerFactory(controllerName, () => this);

    inserter(clone);
    zFactory.instantiate(clone);
  }
}
