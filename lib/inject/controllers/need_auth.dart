/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'package:stratos/drizzle/template.dart';

/// A Drizzle controller that is attached to the "Captures" heading and notifies
/// the user that a manual login is needed.
class NeedAuthController extends TemplateController {
  @override
  String get template => 'need-auth';
}
