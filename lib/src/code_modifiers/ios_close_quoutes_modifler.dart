// ignore_for_file: implementation_imports, unnecessary_import

import 'dart:io';

import 'package:flutter/src/services/text_input.dart';

import '../../code_text_field.dart';

class IOSCloseQuoutesModifier extends CodeModifier {
  const IOSCloseQuoutesModifier() : super('”');

  @override
  TextEditingValue? updateString(String text, TextSelection sel, EditorParams params) {
    if (!Platform.isIOS) {
      return null;
    }
    final tmp = replace(text, sel.start, sel.end, '"');
    return tmp;
  }
}