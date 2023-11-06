// ignore_for_file: implementation_imports, unnecessary_import

import 'dart:io';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/widgets.dart';


class IOSCloseSingleQuouteModifier extends CodeModifier {
  const IOSCloseSingleQuouteModifier() : super('’');

  @override
  TextEditingValue? updateString(String text, TextSelection sel, EditorParams params) {
    if (!Platform.isIOS) {
      return null;
    }
    final tmp = replace(text, sel.start, sel.end, "'");
    return tmp;
  }
}
