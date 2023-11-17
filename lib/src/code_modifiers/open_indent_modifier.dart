import 'dart:math';

import 'package:flutter/widgets.dart';

import '../code_field/editor_params.dart';
import 'code_modifier.dart';

class OpenIndentModifier extends CodeModifier {
  final bool handleBrackets;

  const OpenIndentModifier({
    this.handleBrackets = false,
  }) : super('\n');

  @override
  TextEditingValue? updateString(
    String text,
    TextSelection sel,
    EditorParams params,
  ) {
    final start = sel.start;
    if (start > 1 && start == sel.end && text[start - 1] == ':') {
      final indentCount = getIndentCount(text, sel.start);
      return replace(text, start, sel.end, "\n${' ' * indentCount}${' ' * params.tabSpaces}");
    }
    return null;
  }

  int lineStart(String text, int offset) {
    if (offset == 0) {
      return 0;
    }
    final firstPart = text.substring(0, offset);
    final newLines = RegExp(r'\n').allMatches(firstPart).toList();
    if (newLines.isNotEmpty) {
      final lastMatch = newLines.last;
      return lastMatch.end;
    }
    return 0;
  }

  int lineEnd(String text, int offset) {
    final match = RegExp(r'\n').firstMatch(text.substring(offset));
    if (match == null) {
      return offset;
    } else {
      return match.start + offset;
    }
  }

  int getIndentCount(String text, int offset) {
    final start = lineStart(text, offset);
    final end = lineEnd(text, offset);
    var current = start;
    var count = 0;
    while (current < end && text[current] == ' ') {
      current++;
      count++;
    }
    return count;
  }
}
