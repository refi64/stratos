/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'package:intl/date_symbol_data_local.dart';
import 'package:stratos/drizzle/application.dart';
import 'package:stratos/log.dart';
import 'package:stratos/popup/app.dart';
import 'package:stratos/popup/tabs.dart';

void actualMain() {
  initializeDateFormatting();
  Application.register(TabsController.factory);
  Application.register(AppController.factory);
  Application.attach();
}

void main() => mainWrapper(actualMain);
