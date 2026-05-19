import 'package:flutter/material.dart';

const _palette = [
  Color(0xFFE17076),
  Color(0xFF7BC862),
  Color(0xFF65AADD),
  Color(0xFFA695E7),
  Color(0xFFEE7AAE),
  Color(0xFF6EC9CB),
  Color(0xFFFAA774),
  Color(0xFF98D985),
];

Color avatarColorFor(String seed) {
  if (seed.isEmpty) return _palette[0];
  var hash = 0;
  for (final c in seed.codeUnits) {
    hash = (hash + c) % 0x7fffffff;
  }
  return _palette[hash % _palette.length];
}
