import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../code_theme/code_theme.dart';
import '../line_numbers/line_number_controller.dart';
import '../line_numbers/line_number_style.dart';
import '../query/query_analyzer.dart';
import '../statements/selected_statement_widget.dart';
import 'code_auto_complete.dart';
import 'code_controller.dart';
import 'code_snippet_selector.dart';

class CodeField extends StatefulWidget {
  /// {@macro flutter.widgets.textField.smartQuotesType}
  final SmartQuotesType? smartQuotesType;

  /// {@macro flutter.widgets.textField.keyboardType}
  final TextInputType? keyboardType;

  /// {@macro flutter.widgets.textField.minLines}
  final int? minLines;

  /// {@macro flutter.widgets.textField.maxLInes}
  final int? maxLines;

  /// {@macro flutter.widgets.textField.expands}
  final bool expands;

  /// Whether overflowing lines should wrap around or make the field scrollable horizontally
  final bool wrap;

  /// A CodeController instance to apply language highlight, themeing and modifiers
  final CodeController controller;

  /// A LineNumberStyle instance to tweak the line number column styling
  final LineNumberStyle lineNumberStyle;

  /// {@macro flutter.widgets.textField.cursorColor}
  final Color? cursorColor;

  /// {@macro flutter.widgets.textField.textStyle}
  final TextStyle? textStyle;

  /// A way to replace specific line numbers by a custom TextSpan
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;

  /// {@macro flutter.widgets.textField.enabled}
  final bool? enabled;

  /// {@macro flutter.widgets.editableText.onChanged}
  final void Function(String)? onChanged;

  /// {@macro flutter.widgets.editableText.readOnly}
  final bool readOnly;

  /// {@macro flutter.widgets.textField.isDense}
  final bool isDense;

  /// {@macro flutter.widgets.textField.selectionControls}
  final TextSelectionControls? selectionControls;

  final Color? background;
  final EdgeInsets padding;
  final Decoration? decoration;
  final TextSelectionThemeData? textSelectionTheme;
  final FocusNode? focusNode;
  final void Function()? onTap;
  final bool lineNumbers;
  final bool horizontalScroll;
  final String? hintText;
  final TextStyle? hintStyle;
  final CodeAutoComplete? autoComplete;
  final CodeSnippetSelector? codeSnippetSelector;
  final UndoHistoryController? undoHistoryController;
  final QueryAnalyzer? queryAnalyzer;

  const CodeField({
    super.key,
    required this.controller,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.wrap = false,
    this.background,
    this.decoration,
    this.textStyle,
    this.padding = EdgeInsets.zero,
    this.lineNumberStyle = const LineNumberStyle(),
    this.enabled,
    this.onTap,
    this.readOnly = false,
    this.cursorColor,
    this.textSelectionTheme,
    this.lineNumberBuilder,
    this.focusNode,
    this.onChanged,
    this.isDense = false,
    this.smartQuotesType,
    this.keyboardType,
    this.lineNumbers = true,
    this.horizontalScroll = true,
    this.selectionControls,
    this.hintText,
    this.hintStyle,
    this.autoComplete,
    this.undoHistoryController,
    this.codeSnippetSelector,
    this.queryAnalyzer,
  });

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  final _editorKey = GlobalKey();
  // Add a controller
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  LineNumberController? _numberController;
  OverlayEntry? _statementOverlay;

  StreamSubscription<bool>? _keyboardVisibilitySubscription;
  FocusNode? _focusNode;
  String? lines;
  String longestLine = '';

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();
    _numberController = LineNumberController(widget.lineNumberBuilder);
    widget.controller.addListener(_onTextChanged);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.onKey = _onKey;
    _focusNode!.attach(context, onKey: _onKey);
    _focusNode!.addListener(() {
      if (!_focusNode!.hasFocus) {
        removeStatmentOverlay();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      createAutoComplate();
      createCodeSnippetSelector();

      _codeScroll?.position.isScrollingNotifier.addListener(() {
        if (_codeScroll?.position.isScrollingNotifier.value == false && _focusNode?.hasFocus == true) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            buildStatementOverlay();
          });
        }
      });
    });

    _onTextChanged();
  }

  void removeStatmentOverlay() {
    _statementOverlay?.remove();
    _statementOverlay = null;
    SelectedStatementWidget.setCurrentStatement(context, null);
  }

  void createAutoComplate() {
    widget.controller.autoComplete = widget.autoComplete;
    widget.autoComplete?.show(context, widget, _focusNode!, hideSnippetSelector);
    _codeScroll?.addListener(hideAllPopups);
  }

  void createCodeSnippetSelector() {
    widget.controller.codeSnippetSelector = widget.codeSnippetSelector;
    widget.codeSnippetSelector?.show(context, widget, _focusNode!, hideAutoComplete);
  }

  KeyEventResult _onKey(FocusNode node, RawKeyEvent event) {
    if (widget.readOnly) {
      return KeyEventResult.ignored;
    }

    return widget.controller.onKey(event);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _numberScroll?.dispose();
    _codeScroll?.dispose();
    _numberController?.dispose();
    _keyboardVisibilitySubscription?.cancel();
    widget.autoComplete?.remove();
    super.dispose();
  }

  void rebuild() {
    setState(() {});
  }

  void _onTextChanged() {
    // Rebuild line number
    final str = widget.controller.text.split('\n');
    final buf = <String>[];

    for (var k = 0; k < str.length; k++) {
      buf.add((k + 1).toString());
    }

    _numberController?.text = buf.join('\n');

    // Find longest line
    longestLine = '';
    widget.controller.text.split('\n').forEach((line) {
      if (line.length > longestLine.length) longestLine = line;
    });

    setState(() {});
    if (widget.controller.statementOverlayEnabled) {
      WidgetsBinding.instance.addPostFrameCallback(
        (timeStamp) async {
          await Future.delayed(const Duration(milliseconds: 350));
          buildStatementOverlay();
        },
      );
    }
  }

  Future<void> buildStatementOverlay() async {
    if (_focusNode?.context == null) {
      removeStatmentOverlay();
      return;
    }
    final statmentPosition = await currentStatement();
    if (statmentPosition == null) {
      removeStatmentOverlay();
      return;
    }
    TextStyle textStyle = widget.textStyle ?? const TextStyle();
    final fontSize = textStyle.fontSize ?? 16;
    final theme = Theme.of(context);
    TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(style: textStyle, text: widget.controller.text),
    )..layout();
    final statement = widget.controller.text.substring(statmentPosition.baseOffset, statmentPosition.extentOffset);
    final longestLineWidth = longestLineLength(textStyle, statement) + 24;
    final lineCount = RegExp('\n').allMatches(statement).toList().length;
    final lineHeight = painter.preferredLineHeight;
    final textBoxes = painter.getBoxesForSelection(statmentPosition, boxWidthStyle: BoxWidthStyle.max);
    if (textBoxes.isNotEmpty) {
      final textBox = textBoxes[0];
      final textBoxWidth = textBox.toRect().width + 24;
      final top = textBox.top +
          _focusNode!.offset.dy +
          ((fontSize / 2) * lineNumber(statmentPosition.baseOffset)) -
          _codeScroll!.offset;

      SelectedStatementWidget.setCurrentStatement(context, statement);
      _statementOverlay?.remove();
      _statementOverlay = null;
      _statementOverlay = OverlayEntry(builder: (context) {
        return Positioned(
            left: _focusNode!.offset.dx + textBox.left - 2,
            top: top - lineHeight * 0.6,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: theme.brightness == Brightness.dark ? Colors.white : Colors.black)),
                width: max(longestLineWidth, textBoxWidth),
                height: textBox.toRect().height + lineHeight*0.7 + (lineCount <= 1 ? 0 : (lineCount + 1) * lineHeight ),
              ),
            ));
      });
      final e = _statementOverlay;
      if (e == null) {
        return;
      }
      Overlay.of(context).insert(e);
    } else {
      removeStatmentOverlay();
    }
  }

  double longestLineLength(TextStyle textStyle, String text) {
    final lines = text.split('\n');
    var line = '';
    for (var l in lines) {
      if (l.length > line.length) {
        line = l;
      }
    }
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(style: textStyle, text: line),
    )..layout();
    return painter.size.width;
  }

  int lineNumber(int selectionBase) {
    final firstPart = widget.controller.text.substring(0, selectionBase);
    final newLines = RegExp(r'\n').allMatches(firstPart).toList();
    return newLines.length + 1;
  }

  Future<TextSelection?> currentStatement() async {
    final queryAnalyzer = widget.queryAnalyzer;
    if (queryAnalyzer == null) {
      return null;
    }
    final positions = await queryAnalyzer.statementPositionsAsync(widget.controller.text);
    if (positions.isEmpty) {
      return null;
    }
    var cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0) {
      return null;
    }
    if (cursorPos > 0 && cursorPos < widget.controller.text.length && widget.controller.text[cursorPos] == ' ' ||
        widget.controller.text[cursorPos] == '\n') {
      cursorPos -= 1; //  go back one so we can select if cursor just outside of statement
    }
    for (var pos in positions) {
      final s = widget.controller.text;
      var start = pos.start;
      final end = pos.start + pos.len;
      if (cursorPos >= start && cursorPos <= end) {
        var i = start;
        var count = 0;
        while (i < end && (s[i] == ' ' || s[i] == '\n')) {
          count++;
          i++;
        }
        return TextSelection(baseOffset: start + count, extentOffset: end);
      }
    }
    return null;
  }

  // Wrap the codeField in a horizontal scrollView
  Widget _wrapInScrollView(
    Widget codeField,
    TextStyle textStyle,
    double minWidth,
  ) {
    final leftPad = widget.lineNumberStyle.margin / 2;
    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0,
              minWidth: max(minWidth - leftPad, 0),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(longestLine, style: textStyle),
            ), // Add extra padding
          ),
          widget.expands ? Expanded(key: _editorKey, child: codeField) : codeField,
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: leftPad,
        right: widget.padding.right,
      ),
      scrollDirection: Axis.horizontal,

      /// Prevents the horizontal scroll if horizontalScroll is false
      physics: widget.horizontalScroll ? null : const NeverScrollableScrollPhysics(),
      child: intrinsic,
    );
  }

  void removeAutoComplete() {
    widget.autoComplete?.remove();
  }

  void hideAutoComplete() {
    widget.autoComplete?.hide();
  }

  void hideSnippetSelector() {
    widget.codeSnippetSelector?.hide();
  }

  void hideAllPopups() {
    hideSnippetSelector();
    hideAutoComplete();
  }

  @override
  Widget build(BuildContext context) {
    // Default color scheme
    const rootKey = 'root';
    final defaultBg = Colors.grey.shade900;
    final defaultText = Colors.grey.shade200;

    final styles = CodeTheme.of(context)?.styles;
    Color? backgroundCol = widget.background ?? styles?[rootKey]?.backgroundColor ?? defaultBg;

    if (widget.decoration != null) {
      backgroundCol = null;
    }

    TextStyle textStyle = widget.textStyle ?? const TextStyle();
    textStyle = textStyle.copyWith(
      color: textStyle.color ?? styles?[rootKey]?.color ?? defaultText,
      fontSize: textStyle.fontSize ?? 16.0,
    );

    TextStyle numberTextStyle = widget.lineNumberStyle.textStyle ?? const TextStyle();
    final numberColor = (styles?[rootKey]?.color ?? defaultText).withOpacity(0.7);

    // Copy important attributes
    numberTextStyle = numberTextStyle.copyWith(
      color: numberTextStyle.color ?? numberColor,
      fontSize: textStyle.fontSize,
      fontFamily: textStyle.fontFamily,
    );

    final cursorColor = widget.cursorColor ?? styles?[rootKey]?.color ?? defaultText;

    TextField? lineNumberCol;
    Container? numberCol;

    if (widget.lineNumbers) {
      lineNumberCol = TextField(
        smartQuotesType: widget.smartQuotesType,
        scrollPadding: widget.padding,
        style: numberTextStyle,
        controller: _numberController,
        enabled: false,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        selectionControls: widget.selectionControls,
        expands: widget.expands,
        scrollController: _numberScroll,
        decoration: InputDecoration(
          disabledBorder: InputBorder.none,
          isDense: widget.isDense,
        ),
        textAlign: widget.lineNumberStyle.textAlign,
      );

      numberCol = Container(
        width: widget.lineNumberStyle.width,
        padding: EdgeInsets.only(
          left: widget.padding.left,
          right: widget.lineNumberStyle.margin / 2,
        ),
        color: widget.lineNumberStyle.background,
        child: lineNumberCol,
      );
    }

    final codeField = TextField(
      keyboardType: widget.keyboardType,
      smartQuotesType: widget.smartQuotesType,
      focusNode: _focusNode,
      onTap: () {
        hideAllPopups();
        widget.onTap?.call();
      },
      scrollPadding: widget.padding,
      style: textStyle,
      controller: widget.controller,
      minLines: widget.minLines,
      selectionControls: widget.selectionControls,
      maxLines: widget.maxLines,
      expands: true,
      scrollController: _codeScroll,
      decoration: InputDecoration(
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: widget.isDense,
        hintText: widget.hintText,
        hintStyle: widget.hintStyle,
      ),
      cursorColor: cursorColor,
      autocorrect: false,
      enableSuggestions: false,
      enabled: widget.enabled,
      undoController: widget.undoHistoryController,
      onChanged: (text) {
        widget.onChanged?.call(text);
        widget.autoComplete?.streamController.add(text);
      },
      readOnly: widget.readOnly,
    );

    final codeCol = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: widget.textSelectionTheme,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Control horizontal scrolling
          return widget.wrap ? codeField : _wrapInScrollView(codeField, textStyle, constraints.maxWidth);
        },
      ),
    );

    return Container(
      decoration: widget.decoration,
      color: backgroundCol,
      padding: !widget.lineNumbers ? const EdgeInsets.only(left: 8) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.lineNumbers && numberCol != null) numberCol,
          Expanded(child: codeCol),
        ],
      ),
    );
  }
}
