import 'dart:math';

import 'package:flutter/widgets.dart';

import '../code_field/editor_params.dart';
import 'code_modifier.dart';

class IndentModifier extends CodeModifier {
  final bool handleBrackets;

  const IndentModifier({this.handleBrackets = true, super.priority = 100}) : super('\n');

  @override
  TextEditingValue? updateString(
    String text,
    TextSelection sel,
    EditorParams params,
  ) {
    var spacesCount = 0;
    var braceCount = 0;

    for (var k = min(sel.start, text.length) - 1; k >= 0; k--) {
      if (text[k] == '\n') {
        break;
      }

      if (text[k] == ' ') {
        spacesCount += 1;
      } else {
        spacesCount = 0;
      }

      if (text[k] == '{') {
        braceCount += 1;
      } else if (text[k] == '}') {
        braceCount -= 1;
      }
    }

    if (braceCount > 0) {
      spacesCount += params.tabSpaces;
    }

    if (sel.end <= text.length - 1 && text[sel.end] == '}') {
      final insertWithBrace = '\n${' ' * spacesCount}\n${' ' * (spacesCount - params.tabSpaces)}';
      return replaceWithSelection(text, sel.start, sel.end, insertWithBrace, spacesCount + 1);
    }
    final insert = '\n${' ' * spacesCount}';
    return replace(text, sel.start, sel.end, insert);
  }

    TextEditingValue replaceWithSelection(String text, int start, int end, String str, int offset ) {
    return TextEditingValue(
      text: text.replaceRange(start, end, str),
      selection: TextSelection(
        baseOffset: start + offset,
        extentOffset: start + offset,
      ),
    );
  }
}
