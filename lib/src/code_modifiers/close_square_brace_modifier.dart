import 'package:flutter/widgets.dart';

import '../code_field/editor_params.dart';
import 'code_modifier.dart';

class CloseSquareBraceModifier extends CodeModifier {
  const CloseSquareBraceModifier() : super('[]');

  @override
  TextEditingValue? updateString(
    String text,
    TextSelection sel,
    EditorParams params,
  ) {
    return replace(text, sel.start, sel.end, '[]');
  }
}
