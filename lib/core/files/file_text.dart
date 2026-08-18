import 'dart:convert';

import 'package:cross_file/cross_file.dart';

/// Reads a picked file as UTF-8 text.
///
/// Not [XFile.readAsString], which is a trap: it takes an `encoding`
/// parameter, defaults it to UTF-8, and then — when the XFile holds bytes
/// rather than a path — ignores it and runs `String.fromCharCodes`, which is
/// Latin-1. Android's document picker hands back bytes, so every imported file
/// came through with its diacritics mangled: "svjećica" arriving as
/// "svjeÄica". Nothing threw. The text was simply wrong, which is worse: a
/// Fuelio reminder whose name no longer matched any known service imported as
/// nothing at all, and the user was told three of their intervals were "not
/// recognised" over names they could see were spelled correctly.
///
/// Decoding the bytes ourselves is the whole fix, and it is the same one
/// wherever the file came from.
Future<String> readTextFile(XFile file) async {
  final bytes = await file.readAsBytes();
  // Malformed input is replaced rather than thrown: a file in some other
  // encoding should import as much of itself as it can, instead of failing
  // whole over one byte.
  final text = utf8.decode(bytes, allowMalformed: true);
  // A spreadsheet on Windows writes a byte-order mark, which would otherwise
  // become an invisible first character of the first header — which is how a
  // column stops being found.
  return text.startsWith('﻿') ? text.substring(1) : text;
}
