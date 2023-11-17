import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlighting/highlighting.dart';
import 'package:highlighting/languages/xml.dart';
import 'package:highlighting/src/language.dart';

import '../code_modifiers/close_block_code_modifier.dart';
import '../code_modifiers/code_modifier.dart';
import '../code_modifiers/indent_code_modifier.dart';
import '../code_modifiers/ios_close_quoutes_modifler.dart';
import '../code_modifiers/ios_close_single_quoute_modifier.dart';
import '../code_modifiers/ios_open_quotes_modifier.dart';
import '../code_modifiers/ios_opens_single_quote_modifier.dart';
import '../code_modifiers/tab_code_modifier.dart';
import '../code_theme/code_theme.dart';
import '../code_theme/code_theme_data.dart';
import 'code_auto_complete.dart';
import 'code_snippet_selector.dart';
import 'editor_params.dart';
import 'mode_comments.dart';

class CodeController extends TextEditingController {
  Language? _language;
  CodeAutoComplete? autoComplete;
  CodeSnippetSelector? codeSnippetSelector;

  /// A highlight language to parse the text with
  Language? get language => _language;

  set language(Language? language) {
    if (language == _language) {
      return;
    }

    if (language != null) {
      _languageId = language.hashCode.toString();
      highlight.registerLanguage(language, id: _languageId);
    }

    _language = language;
    notifyListeners();
  }

  /// A map of specific regexes to style
  final Map<String, TextStyle>? patternMap;

  /// A map of specific keywords to style
  final Map<String, TextStyle>? stringMap;

  /// Common editor params such as the size of a tab in spaces
  ///
  /// Will be exposed to all [modifiers]
  final EditorParams params;

  /// A list of code modifiers to dynamically update the code upon certain keystrokes
  final List<CodeModifier> modifiers;

  /* Computed members */
  String _languageId = '';
  final _modifierMap = <String, CodeModifier>{};
  final _styleList = <TextStyle>[];
  RegExp? _styleRegExp;

  String get languageId => _languageId;

  CodeController({
    super.text,
    Language? language,
    this.patternMap,
    this.stringMap,
    this.params = const EditorParams(),
    this.modifiers = const [
      IndentModifier(),
      CloseBlockModifier(),
      TabModifier(),
      IOSOpenQuoutesModifier(),
      IOSCloseQuoutesModifier(),
      IOSOpenSingleQuouteModifier(),
      IOSCloseSingleQuouteModifier()
    ],
  }) {
    this.language = language;

    // Create modifier map
    for (final el in modifiers) {
      _modifierMap[el.char] = el;
    }

    // Build styleRegExp
    final patternList = <String>[];
    if (stringMap != null) {
      patternList.addAll(stringMap!.keys.map((e) => r'(\b' + e + r'\b)'));
      _styleList.addAll(stringMap!.values);
    }
    if (patternMap != null) {
      patternList.addAll(patternMap!.keys.map((e) => '($e)'));
      _styleList.addAll(patternMap!.values);
    }
    _styleRegExp = RegExp(patternList.join('|'), multiLine: true);
  }

  /// Sets a specific cursor position in the text
  void setCursor(int offset) {
    selection = TextSelection.collapsed(offset: offset);
  }

  /// Replaces the current [selection] by [str]
  void insertStr(String str) {
    final sel = selection;
    text = text.replaceRange(selection.start, selection.end, str);
    final len = str.length;

    selection = sel.copyWith(
      baseOffset: sel.start + len,
      extentOffset: sel.start + len,
    );
  }

  /// Remove the char just before the cursor or the selection
  void removeChar() {
    if (selection.start < 1) {
      return;
    }

    final sel = selection;
    text = text.replaceRange(selection.start - 1, selection.start, '');

    selection = sel.copyWith(
      baseOffset: sel.start - 1,
      extentOffset: sel.start - 1,
    );
  }

  /// Remove the selected text
  void removeSelection() {
    final sel = selection;
    text = text.replaceRange(selection.start, selection.end, '');

    selection = sel.copyWith(
      baseOffset: sel.start,
      extentOffset: sel.start,
    );
  }

  /// Remove the selection or last char if the selection is empty
  void backspace() {
    if (selection.start < selection.end) {
      removeSelection();
    } else {
      removeChar();
    }
  }

  KeyEventResult onKey(RawKeyEvent event) {
    if (event.isKeyPressed(LogicalKeyboardKey.tab)) {
      text = text.replaceRange(selection.start, selection.end, '\t');
      return KeyEventResult.handled;
    }

    if (autoComplete?.isShowing ?? false) {
      if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
        autoComplete!.current = (autoComplete!.current + 1) % autoComplete!.options.length;
        autoComplete!.panelSetState?.call(() {});
        return KeyEventResult.handled;
      }
      if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
        autoComplete!.current = (autoComplete!.current - 1) % autoComplete!.options.length;
        autoComplete!.panelSetState?.call(() {});
        return KeyEventResult.handled;
      }
      if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
        autoComplete!.writeCurrent();
        return KeyEventResult.handled;
      }
      if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
        autoComplete!.hide();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  int? _insertedLoc(String a, String b) {
    final sel = selection;

    if (a.length + 1 != b.length || sel.start != sel.end || sel.start < 0) {
      return null;
    }

    return sel.start;
  }

  void indentSelection() {
    final tabSpaces = params.tabSpaces;
    final tab = ' ' * tabSpaces;
    if (selection.start == -1 || selection.end == -1) {
      return;
    }
    final selStart = selection.start;
    final selEnd = selection.end;
    final start = lineStart(selection.start);
    final end = lineEnd(selection.end);

    final selectedText = text.substring(start, end);
    var lines = selectedText.split('\n');
    lines = lines
        .map(
          (e) => tab + e,
        )
        .toList();
    final indented = lines.join('\n');
    text = text.replaceRange(start, end, indented);
    selection = TextSelection(baseOffset: selStart + tabSpaces, extentOffset: selEnd + (tabSpaces * lines.length));
  }

  void unIndentSelection() {
    final tabSpaces = params.tabSpaces;
    final tab = ' ' * tabSpaces;
    if (selection.start == -1 || selection.end == -1) {
      return;
    }
    final selStart = selection.start;
    final selEnd = selection.end;
    final start = lineStart(selection.start);
    final end = lineEnd(selection.end);
    final selectedText = text.substring(start, end);
    var lines = selectedText.split('\n');
    var newSelection = (start: selStart, end: selEnd);
    var modified = false;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.startsWith(tab)) {
        modified = true;
        lines[i] = l.substring(tab.length);
        if (i == 0) {
          newSelection = (start: max(0, newSelection.start - tabSpaces), end: newSelection.end - tabSpaces);
        } else {
          newSelection = (start: newSelection.start, end: max(0, newSelection.end - tabSpaces));
        }
      }
    }
    if (!modified) {
      return;
    }
    final unIndented = lines.join('\n');
    text = text.replaceRange(start, end, unIndented);
    selection = TextSelection(baseOffset: newSelection.start, extentOffset: newSelection.end);
  }

  void commentSelection() {
    final comment = _language?.getComment();
    if (comment == null) {
      return;
    }
    if (selection.start == -1 || selection.end == -1) {
      return;
    }
    final selStart = selection.start;
    final selEnd = selection.end;
    final start = lineStart(selection.start);
    final end = lineEnd(selection.end);

    final selectedText = text.substring(start, end);
    var lines = selectedText.split('\n');
    lines = lines
        .map(
          (e) => comment + e,
        )
        .toList();
    final commented = lines.join('\n');
    text = text.replaceRange(start, end, commented);
    selection =
        TextSelection(baseOffset: selStart + comment.length, extentOffset: selEnd + (comment.length * lines.length));
  }

  void commentMultiLanguageSelection(Language secondaryLang) {
    if (selection.start == -1 || selection.end == -1) {
      return;
    }
    final selStart = selection.start;
    final selEnd = selection.end;
    final start = lineStart(selection.start);
    final end = lineEnd(selection.end);

    final selectedText = text.substring(start, end);

    var lines = selectedText.split('\n');
    final addedChars = lines
        .map(
          (e) => commentLine(e, secondaryLang: secondaryLang),
        )
        .toList();
    lines = addedChars.map((e) => e.$1).toList();
    final addedCount = addedChars.map((e) => e.$2 + e.$3).reduce((value, element) => value + element);
    final commented = lines.join('\n');
    text = text.replaceRange(start, end, commented);
    selection =
        TextSelection(baseOffset: selStart + addedChars[0].$2, extentOffset: selEnd + (addedCount - addedChars[0].$3));
  }

  (String, int, int) commentLine(String line, {Language? secondaryLang}) {
    var result = highlight.parse(line, languageId: xml.id);
    if (result.relevance >= 0.9) {
      return ('<!--$line-->', 4, 3);
    }
    final comment = secondaryLang?.getComment() ?? _language?.getComment();
    if (comment == null) {
      return (line, 0, 0);
    }
    return ('$comment$line', comment.length, 0);
  }

  void unCommentSelection() {
    final comment = _language?.getComment();
    if (comment == null) {
      return;
    }
    if (selection.start == -1 || selection.end == -1) {
      return;
    }
    final selStart = selection.start;
    final selEnd = selection.end;
    final start = lineStart(selection.start);
    final end = lineEnd(selection.end);

    final selectedText = text.substring(start, end);
    var lines = selectedText.split('\n');
    var newSelection = (start: selStart, end: selEnd);
    var modified = false;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.startsWith(RegExp(r'\s*' + comment))) {
        modified = true;
        lines[i] = l.replaceFirst(comment, '');
        if (i == 0) {
          newSelection = (start: max(0, newSelection.start - comment.length), end: newSelection.end - comment.length);
        } else {
          newSelection = (start: newSelection.start, end: max(0, newSelection.end - comment.length));
        }
      }
    }
    if (!modified) {
      return;
    }
    final unCommented = lines.join('\n');
    text = text.replaceRange(start, end, unCommented);
    selection = TextSelection(baseOffset: newSelection.start, extentOffset: min(text.length, newSelection.end));
  }

  void unCommentMulitModeSelection(Language secondaryLang) {
    final comment = secondaryLang.getComment();
    if (comment == null) {
      return;
    }
    if (selection.start == -1 || selection.end == -1) {
      return;
    }
    final selStart = selection.start;
    final selEnd = selection.end;
    final start = lineStart(selection.start);
    final end = lineEnd(selection.end);

    final selectedText = text.substring(start, end);
    var lines = selectedText.split('\n');
    var newSelection = (start: selStart, end: selEnd);
    var modified = false;
    for (var i = 0; i < lines.length; i++) {
      modified = true;
      final l = lines[i];
      final isXml = highlight.parse(l, languageId: xml.id).relevance > 0.7;
      if (isXml && RegExp('<!--(.*?)-->').hasMatch(l)) {
        lines[i] = l.replaceFirst(RegExp('<!--'), '').replaceAll('-->', '');
        if (i == 0) {
          newSelection = (start: max(0, newSelection.start - 4), end: newSelection.end - 4);
        } else {
          newSelection = (start: newSelection.start, end: max(0, newSelection.end - 7));
        }
      } else if (l.startsWith(RegExp(r'\s*' + comment))) {
        modified = true;
        lines[i] = l.replaceFirst(comment, '');
        if (i == 0) {
          newSelection = (start: max(0, newSelection.start - comment.length), end: newSelection.end - comment.length);
        } else {
          newSelection = (start: newSelection.start, end: max(0, newSelection.end - comment.length));
        }
      }
    }
    if (!modified) {
      return;
    }
    final unCommented = lines.join('\n');
    text = text.replaceRange(start, end, unCommented);
    selection = TextSelection(baseOffset: newSelection.start, extentOffset: min(text.length, newSelection.end));
  }

  int lineStart(int offset) {
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

  int lineEnd(int offset) {
    final match = RegExp(r'\n').firstMatch(text.substring(offset));
    if (match == null) {
      return offset;
    } else {
      return match.start + offset;
    }
  }

  @override
  set value(TextEditingValue newValue) {
    final loc = _insertedLoc(text, newValue.text);

    if (loc != null) {
      final char = newValue.text[loc];
      final modifier = _modifierMap[char];
      final val = modifier?.updateString(super.text, selection, params);

      if (val != null) {
        // Update newValue
        newValue = newValue.copyWith(
          text: val.text,
          selection: val.selection,
        );
      }
    }
    super.value = newValue;
  }

  TextSpan _processPatterns(String text, TextStyle? style) {
    final children = <TextSpan>[];

    text.splitMapJoin(
      _styleRegExp!,
      onMatch: (Match m) {
        if (_styleList.isEmpty) {
          return '';
        }

        int idx;
        for (idx = 1; idx < m.groupCount && idx <= _styleList.length && m.group(idx) == null; idx++) {}

        children.add(TextSpan(
          text: m[0],
          style: _styleList[idx - 1],
        ));
        return '';
      },
      onNonMatch: (String span) {
        children.add(TextSpan(text: span, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }

  TextSpan _processLanguage(
    String text,
    CodeThemeData? widgetTheme,
    TextStyle? style,
  ) {
    final result = highlight.parse(text, languageId: language!.id);
    final nodes = result.nodes;

    final children = <TextSpan>[];
    var currentSpans = children;
    final stack = <List<TextSpan>>[];

    void traverse(Node node) {
      var val = node.value;
      final nodeChildren = node.children;
      final nodeStyle = widgetTheme?.styles[node.className];

      if (val != null) {
        var child = TextSpan(text: val, style: nodeStyle);

        if (_styleRegExp != null) {
          child = _processPatterns(val, nodeStyle);
        }

        currentSpans.add(child);
      } else if (nodeChildren != null) {
        List<TextSpan> tmp = [];

        currentSpans.add(TextSpan(
          children: tmp,
          style: nodeStyle,
        ));

        stack.add(currentSpans);
        currentSpans = tmp;

        for (final n in nodeChildren) {
          traverse(n);
          if (n == nodeChildren.last) {
            currentSpans = stack.isEmpty ? children : stack.removeLast();
          }
        }
      }
    }

    if (nodes != null) {
      nodes.forEach(traverse);
    }

    return TextSpan(style: style, children: children);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }) {
    // Return parsing
    if (_language != null) {
      return _processLanguage(text, CodeTheme.of(context), style);
    }
    if (_styleRegExp != null) {
      return _processPatterns(text, style);
    }
    return TextSpan(text: text, style: style);
  }
}
