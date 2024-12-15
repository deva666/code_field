import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../code_theme/code_theme.dart';
import '../line_numbers/line_number_controller.dart';
import '../line_numbers/line_number_style.dart';
import 'code_analysis.dart';
import 'code_auto_complete.dart';
import 'code_controller.dart';
import 'code_snippet_selector.dart';
import 'event_dispatcher.dart';

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
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final Stream<List<CodeAnalysis>>? errorStream;

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
    this.contextMenuBuilder,
    this.errorStream,
  });

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  final customPaintKey = GlobalKey();

  late final _ErrorLinesPainter errorLinesPainer;
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  LineNumberController? _numberController;
  CodeFieldEventDispatcher? _eventDispatcher;
  StreamSubscription<bool>? _keyboardVisibilitySubscription;
  StreamSubscription<List<CodeAnalysis>>? _errorsSubscription;

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
    errorLinesPainer = _ErrorLinesPainter(customPaintKey,
        widget.textStyle ?? const TextStyle(), Listenable.merge([_codeScroll]));
    _errorsSubscription = widget.errorStream?.listen((event) {
      errorLinesPainer.errors = event;
      _onTextChanged();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      createAutoComplate();
      createCodeSnippetSelector();
      _eventDispatcher = CodeFieldEventDispatcher.of(context)
        ?..addListener(onCodeFieldEvent);
    });

    _onTextChanged();
    widget.controller.focusCallback.add(focusCallback);
  }

  void focusCallback() {
    _focusNode?.requestFocus();
  }

  void onCodeFieldEvent(CodeFieldEvent e) {
    errorLinesPainer.errors = [];
    setState(() {});
  }

  void createAutoComplate() {
    widget.controller.autoComplete = widget.autoComplete;
    widget.autoComplete
        ?.show(context, widget, _focusNode!, hideSnippetSelector);
    _codeScroll?.addListener(hideAllPopups);
  }

  void createCodeSnippetSelector() {
    widget.controller.codeSnippetSelector = widget.codeSnippetSelector;
    widget.codeSnippetSelector
        ?.show(context, widget, _focusNode!, hideAutoComplete);
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
    _errorsSubscription?.cancel();
    _eventDispatcher?.removeListener(onCodeFieldEvent);
    widget.controller.focusCallback.remove(focusCallback);
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
    final lineNumsWithlongestError = <int, String>{};
    final longestError = errorLinesPainer.errors.isEmpty
        ? ''
        : errorLinesPainer.errors.length == 1
            ? errorLinesPainer.errors[0].text
            : errorLinesPainer.errors
                .map((e) => e.text)
                .reduce((l, r) => l.length >= r.length ? l : r);
    for (final e in errorLinesPainer.errors) {
      lineNumsWithlongestError[e.lineNumber - 1] = e.text;
    }
    final lines = widget.controller.text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = '${lines[i]}$longestError    ';
      //if (lineNumsWithlongestError.containsKey(i)) {
      //line += '${lineNumsWithlongestError[i]!}          ';
      //}
      if (line.length > longestLine.length) {
        longestLine = line;
      }
    }
    errorLinesPainer.code = widget.controller.text;
    setState(() {});
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
          widget.expands ? Expanded(child: codeField) : codeField,
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
      physics:
          widget.horizontalScroll ? null : const NeverScrollableScrollPhysics(),
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
    Color? backgroundCol =
        widget.background ?? styles?[rootKey]?.backgroundColor ?? defaultBg;

    if (widget.decoration != null) {
      backgroundCol = null;
    }

    TextStyle textStyle = widget.textStyle ?? const TextStyle();
    textStyle = textStyle.copyWith(
      color: textStyle.color ?? styles?[rootKey]?.color ?? defaultText,
      fontSize: textStyle.fontSize ?? 16.0,
    );

    TextStyle numberTextStyle =
        widget.lineNumberStyle.textStyle ?? const TextStyle();
    final numberColor =
        (styles?[rootKey]?.color ?? defaultText).withOpacity(0.7);

    // Copy important attributes
    numberTextStyle = numberTextStyle.copyWith(
      color: numberTextStyle.color ?? numberColor,
      fontSize: textStyle.fontSize,
      fontFamily: textStyle.fontFamily,
    );

    final cursorColor =
        widget.cursorColor ?? styles?[rootKey]?.color ?? defaultText;

    TextField? lineNumberCol;
    Container? numberCol;

    if (widget.lineNumbers) {
      lineNumberCol = TextField(
        onTap: hideAllPopups,
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

    final codeField = DumbVisitor(
      onFound: errorLinesPainer.setupEditableTextState,
      child: CustomPaint(
        foregroundPainter: errorLinesPainer,
        key: customPaintKey,
        child: TextField(
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
          contextMenuBuilder: widget.contextMenuBuilder,
          undoController: widget.undoHistoryController,
          onChanged: (text) {
            widget.onChanged?.call(text);
            widget.autoComplete?.streamController.add(text);
          },
          readOnly: widget.readOnly,
        ),
      ),
    );

    final codeCol = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: widget.textSelectionTheme,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Control horizontal scrolling
          return widget.wrap
              ? codeField
              : _wrapInScrollView(codeField, textStyle, constraints.maxWidth);
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

class _ErrorLinesPainter extends CustomPainter {
  _ErrorLinesPainter(this.customPaintKey, this.textStyle, Listenable listenable)
      : super(repaint: listenable);
  GlobalKey customPaintKey;
  RenderEditable? re;

  final TextStyle textStyle;

  List<CodeAnalysis> errors = [];

  String code = '';

  @override
  void paint(Canvas canvas, Size size) {
    if (code.isEmpty) {
      return;
    }
    if (re case RenderEditable re) {
      final ancestor = customPaintKey.currentContext!.findRenderObject();
      final offset = re.localToGlobal(Offset.zero, ancestor: ancestor);
      final lineEndPositions = <int>{};
      for (final e in errors) {
        int selectionStart;
        int selectionEnd;
        int lineStartOffset;
        int lineEndOffset;
        if (e.baseOffset != null && e.offsetLength != null) {
          lineStartOffset = lineStart(e.lineNumber);
          lineEndOffset = lineEnd(lineStartOffset);
          selectionStart = e.baseOffset!;
          selectionEnd = lineEndOffset;
          //lineStartOffset = 0; // does not matter
          //selectionStart = max(0, e.baseOffset!);
          //lineEndOffset = lineEnd(selectionStart);
          //selectionEnd = lineEndOffset;
          //if (selectionStart == selectionEnd) {
            //selectionStart--; // if selection empty then nothing will be highlighted
          //}
        } else {
          lineStartOffset = lineStart(e.lineNumber);
          lineEndOffset = lineEnd(lineStartOffset);
          // if column is on the end of the line, highlight the whole line
          selectionStart = e.column > (lineEndOffset - lineStartOffset)
              ? lineStartOffset
              : lineStartOffset + e.column - 1;
          selectionEnd = lineEndOffset;
        } 
        if (lineEndPositions.contains(lineEndOffset)) {
          continue;
        } else {
          lineEndPositions.add(lineEndOffset);
        }
        final boxes = re.getBoxesForSelection(TextSelection(
            baseOffset: selectionStart, extentOffset: selectionEnd));
        if (boxes.isNotEmpty) {
          final firstBox = boxes.first.toRect();
          final lastBox = boxes.last.toRect();
          canvas.drawLine(
              Offset(firstBox.left + offset.dx, firstBox.bottom + offset.dy),
              Offset(lastBox.right + offset.dx, firstBox.bottom + offset.dy),
              Paint()
                ..strokeWidth = 1.5
                ..style = PaintingStyle.stroke
                ..filterQuality = FilterQuality.low
                ..strokeCap = StrokeCap.round
                ..color = Colors.red.shade300);
          final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
            textAlign: TextAlign.left,
            fontSize: 14,
          ))
            ..pushStyle(ui.TextStyle(
                color: Theme.of(customPaintKey.currentContext!).brightness ==
                        Brightness.dark
                    ? Colors.white24
                    : Colors.black26))
            ..addText(e.text);
          final paragraph = paragraphBuilder.build()
            ..layout(const ui.ParagraphConstraints(width: 1000));
          canvas.drawParagraph(paragraph,
              Offset(lastBox.right + offset.dx + 6, firstBox.top + offset.dy));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ErrorLinesPainter oldDelegate) => false;

  void setupEditableTextState(EditableTextState ets) {
    re = ets.renderEditable;
  }

  int lineStart(int lineNum) {
    if (lineNum == 1) {
      return 0;
    }
    final lines = code.split('\n');
    if (lineNum > lines.length) {
      return code.length - 1;
    } else {
      return lines.sublist(0, lineNum - 1).join('\n').length + 1;
    }
  }

  int lineEnd(int offset) {
    final match =
        RegExp(r'\n').firstMatch(code.substring(min(code.length - 1, offset)));
    if (match == null) {
      return code.length;
    } else {
      return match.start + offset;
    }
  }
}

class DumbVisitor<T> extends StatelessWidget {
  const DumbVisitor({
    super.key,
    required this.onFound,
    required this.child,
  });

  final void Function(T object) onFound;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;

  @override
  StatelessElement createElement() => _DumbVisitorElement<T>(this, onFound);
}

class _DumbVisitorElement<T> extends StatelessElement {
  _DumbVisitorElement(super.widget, this.onFound);

  final void Function(T object) onFound;
  Element? oldElement;

  @override
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    final element = super.updateChild(child, newWidget, newSlot);
    if (oldElement != element) {
      oldElement = element;
      element?.visitChildren(_visitor);
    }
    return element;
  }

  void _visitor(Element child) {
    if (child is StatefulElement && child.state is T) {
      onFound(child.state as T);
    } else if (child.renderObject is T) {
      onFound(child.renderObject as T);
    }
    child.visitChildren(_visitor);
  }
}
