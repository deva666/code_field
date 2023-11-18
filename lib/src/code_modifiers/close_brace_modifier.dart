import 'package:flutter/widgets.dart';

import '../code_field/editor_params.dart';
import 'code_modifier.dart';

class CloseBraceModifier extends CodeModifier {
  const CloseBraceModifier() : super('(');

  @override
  TextEditingValue? updateString(
    String text,
    TextSelection sel,
    EditorParams params,
  ) {
    return replace(text, sel.start, sel.end, '()');
  }
}
