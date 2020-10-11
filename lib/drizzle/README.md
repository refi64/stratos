# stratos.drizzle

Drizzle is a terrible, vaguely Stimulus/Wiz-inspired client-side web framework,
designed to be easily added to an existing page. This makes it well-suited for
Stratos's use case, which heavily involves adding custom HTML and controllers
to the Stadia captures page.

The main goals were:

- No code generators required. Stratos requires use of dart2js, so the build
  times can be long, and I don't want to add to that.
- Very basic. This exists just to make the code a bit cleaner than trying to
  use raw DOM queries & manipulations *everywhere*.
- Needs to be able to easily argment existing DOM. Since Stratos injects DOM
  elements into the Stadia captures page, there should be some ability to
  add some custom functionality and DOM elements without needing to control
  the entire page content.

## Controllers

Drizzle is built around the idea of attaching controllers to an HTML element.
Consider the following HTML:

```html
<body>
  <div dz-controller="app"></div>
</body>
```

We can create a controller for this element using the following code:

```dart
import 'package:stratos/drizzle/controller.dart';

class AppController extends Controller {
  static final factory = ControllerFactory<AppController>(
    // This is the controller name.
    'app',
    // This is a factory function returning a controller instance.
    () => AppController._()
  );

  AppController._();

  // This is called when the controller is attached to the DOM.
  @override
  void onAttach() {
    // `element` is the attached DOM element.
    element.innerText = 'Controller attached!';
  }
}
```

Now, it can be globally registered and bound:

```dart
import 'package:stratos/drizzle/application.dart';

void main() {
  // Register the controller factory.
  Application.register(AppController.factory);
  // Attach all controllers.
  Application.attach();
}
```

Note that, unlike with Stimulus, each element can have only one controller.
This is partly for template controllers (see below), but also simply because
it's easier to implement.

## Actions

Each controller can install "actions" onto itself, then other DOM nodes can
have their events trigger these actions. Example:

```html
<body>
  <div dz-controller="app">
    <button dz-actions="click:app:click">Click me!</button>
    <span id="out"></span>
  </div>
</body>
```

Notice the `dz-actions` attribute. An element can have multiple actions in
the format `event:controller:action`, where `event` is the DOM event name,
`controller` is the controller the action is installed onto, and `action` is
the name of the action to invoke when the event occurs. (If you want multiple
actions declared per element, separate them using semicolons.) Here is the new
controller code:

```dart
class AppController extends Controller {
  // factory definition is the same...

  AppController._() {
    installActions({'click': _onClick});
  }

  Element _outElement;

  @override
  void onAttach() {
    // There's a button now, so we can't clobber the entire inner content. Thus,
    // the text now goes into the "out" element instead.
    _outElement = element.querySelector('#out');
    _outElement.innerText = 'Ready to click...';
  }

  void _onClick(Element target, Event event) {
    _outElement.innerText = 'The button was clicked!';
  }
}
```

This installs one named action called "click". Now, if you click the button,
the text content will be updated to show that a click occurred.

In this case, since the DOM event and action have the same name, the action name
can actually be omitted from the HTML:

```html
<button dz-actions="click:app">
```

Note that controllers for actions are looked up going outwards:

```html
<div dz-controller="outer">
  <button dz-actions="click:outer">Click me</button>
  <div dz-controller="inner">
    <button dz-actions="click:inner">Click me too!</button>
  </div>
</div>
```

Note that *all* controllers are attached (and thus, their `onAttach` methods
are called) before any actions are. If you want to invoke a controller method
*after* actions are attached, override `void onReady()`.

### The `attach` action

A special, synthesized DOM event is available called "attach", which is invoked
right as the DOM element's actions are attached. Example:

```html
<button dz-actions="attach:app;click:app">
```

The app controller's code can be updated as such:

```dart
AppController._() {
  installActions({'attach': _onActionsAtached, 'click': _onClick});
}

// ...
void _onActionsAttached(Element target, Event event) {
  print('The following element actions are being attached right now: $target');
}
```

Note that, with this action, `event` is *always* `null` (for now).

## Content subjects
In the above example, the text output element's `innerText` is always manually
updated. As a slightly more elegant alternative, content subjects are available:

```html
<body>
  <div dz-controller="app">
    <button dz-actions="click:app:click">Click me!</button>
    <span dz-content="app:textOutput"></span>
  </div>
</body>
```

This attaches the app controller's `textOutput` content subject to the span's
`innerText`. Now, the controller can be updated as such:

```dart
class AppController extends Controller {
  // ...factory stays the same

  BehaviorSubject<String> _outputSubject;

  AppController._() {
    installActions(/* ... */);

    _outputSubject = acquireContentSubject('textOuptut',
                      seed: 'Ready to click...');
  }

  // ...
  void _onClick(Element target, Event event) {
    _outputSubject.add('The button was clicked!');
  }
}
```

A content subject is represented by an RxDart
[BehaviorSubject](https://pub.dev/documentation/rxdart/latest/rx/BehaviorSubject-class.html).
When the subject is seeded or an element is added to its sink, the content of
the corresponding DOM node will be updated. Content subjects can also be
attached to attributes, e.g.:

```html
<img dz-content="src:app:imageUrl">
```

This would attach the `img` element's `src` attribute to the controller's
`imageUrl` content subject.

Note that `BehaviorSubject`s will be auto-closed on element detach and do not
need to be closed manually.

## Template controllers

Rather than being attached on app startup, a controller can be instantiated
only when needed, and it can have HTML that goes along with it. Here is an
example of an alternative way of creating our app controller:

```html
<body>
  <div id="app"></div>
</body>

<template dz-template="app">
  <div>
    <button dz-actions="click:app:click">Click me!</button>
    <span dz-content="app:textOutput"></span>
  </div>
</template>
```

Here, a `template` element is added containing some HTML. This template will
later be attached to the `app` element, replacing its entire DOM node with
the root element of the template. In addition, the template's root element
will have its associated controller automatically attached to it. The template
controller Dart code can be created as such:

```dart
class AppController extends TemplateController {
  // The template to attach to, searched via [dz-template='app'].
  @override
  final String template = 'app';

  // Other methods are the same...
}
```

Note that there is no longer any factory. Now, the code to initialize it looks
as such:

```dart
void main() {
  var app = AppController();
  app.instantiateReplacing(document.querySelector('#app'));
}
```

This will completely replace the `#app` element with the controller's template.
Note that all attributes of `#app` will also be replaced; if you want to
preserve those, use `<div id="app" dz-preserve>`. In addition, an
`instantiateInto` method is available, to instantiate the template as the child
of another element, rather than replacing another element.

One more note: template controllers have no scope attached to them. If the
template has any `dz-actions` attributes, they can bind to controllers right
outside instantiation point, as if the template contents were directly inlined
there.

## Closing notes

This is pretty much a high level summary of Drizzle and how Stratos uses it.
There are definitely some nasty warts, but it's pretty much "good enough" for
our purposes (and was also written in a very short time span). In the future,
I sort of like the idea of expanding on it and cleaning it up as a separate Dart
package, but that's beyond my current time constraints for now.
