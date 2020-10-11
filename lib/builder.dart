/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';

/// A basic [Builder] that merges JSON files together. This is used to keep the
/// OAuth tokens and extension keys outside of the main manifest file.
/// A JSON file simply needs to contain `//!merge:filename`, and the given file
/// will be merged with this one.
class MergeJsonBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
        '.base.json': ['.json']
      };

  dynamic _merge(dynamic a, dynamic b) {
    // Merge rules:
    // - If types differ, then b always overrides a.
    // - If both are objects, their values are merged using these same rules
    //   if a key is specified by both. Any new keys in b are just dropped in a
    //   directly.

    if (a is Map) {
      if (b is! Map) {
        return b;
      }

      for (var entry in b.entries) {
        if (a[entry.key] is Map) {
          a[entry.key] = _merge(a[entry.key], entry.value);
        } else {
          a[entry.key] = entry.value;
        }
      }

      return a;
    }
  }

  // Manifests can have commented JSON, but Dart won't parse that, so strip out
  // all the single-line comments before parsing.
  dynamic _parseCommentedJson(String content) =>
      json.decode(content.replaceAll(RegExp(r'^\s*//.*', multiLine: true), ''));

  @override
  Future<void> build(BuildStep buildStep) async {
    var content = await buildStep.readAsString(buildStep.inputId);
    dynamic obj = _parseCommentedJson(content);

    for (var match
        in RegExp(r'^\s*//!merge:(.+)', multiLine: true).allMatches(content)) {
      var path = match.group(1);
      var id = AssetId.resolve(path, from: buildStep.inputId);
      dynamic toMerge = _parseCommentedJson(await buildStep.readAsString(id));
      obj = _merge(obj, toMerge);
    }

    var encoder = JsonEncoder.withIndent(' ' * 2);
    await buildStep.writeAsString(
        buildStep.inputId.changeExtension('').changeExtension('.json'),
        encoder.convert(obj));
  }
}

Builder mergeJsonBuilder(BuilderOptions options) => MergeJsonBuilder();
