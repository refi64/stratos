/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'package:aspen/aspen.dart';
import 'package:aspen_assets/aspen_assets.dart';

part 'assets.g.dart';

// NOTE: Why not just use getURL? Well, that would involve more async requests,
// which is just a bit messier to handle.

@Asset('asset:stratos/lib/inject/inject.html')
const injectedHtml = TextAsset(text: _injectedHtml$content);
