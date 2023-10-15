import 'dart:async';
import 'dart:ffi';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart';
import '../../code_text_field.dart';

typedef OffsetFunc = Offset Function();

class CodeAutoComplete<T> {
  /// can input your options which created through editor text and language.
  List<T> Function(String, int cursorIndex, Mode?) optionsBuilder;

  /// depends on your options, you can create your own item widget.
  final Widget Function(BuildContext, T, bool, Function(String) onTap) itemBuilder;

  /// set the tip panel size.
  final BoxConstraints constraints;

  /// set the tip panel background color.
  final Color? backgroundColor;

  /// the tip panel display status.
  bool isShowing = false;

  /// the tip panel current index of items.
  int current = 0;

  /// the tip panel set state function.
  void Function(void Function())? panelSetState;

  /// the code field widget.
  late CodeField widget;

  /// a getter function to get the text value from option<T>, default to toString
  String Function(T)? optionValue;

  /// the options list.
  List<T> options = [];

  /// the panel offset.
  OffsetFunc? offsetFunc;
  StreamController streamController;
  Stream get stream => streamController.stream;

  CodeAutoComplete({
    required this.optionsBuilder,
    required this.itemBuilder,
    required this.streamController,
    this.offsetFunc,
    this.constraints = const BoxConstraints(maxHeight: 300, maxWidth: 240),
    this.backgroundColor,
    this.optionValue,
  });

  OverlayEntry? panelOverlay;

  /// remove the tip panel.
  void remove() {
    panelOverlay?.addListener(() {});
    if (panelOverlay != null) panelOverlay?.remove();
    panelOverlay = null;
  }

  /// hide the tip panel.
  void hide() {
    streamController.add(null);
  }

  /// create and show the tip panel.
  void show(BuildContext codeFieldContext, CodeField wdg, FocusNode focusNode, ScrollController codeScroll, GlobalKey editorKey) {
    widget = wdg;
    OverlayEntry overlayEntry = OverlayEntry(
        maintainState: true,
        builder: (context) {
          return StreamBuilder(
            stream: stream,
            builder: (context, snapshot) {
              isShowing = false;
              current = 0;
              options = optionsBuilder(
                widget.controller.text,
                widget.controller.selection.baseOffset,
                widget.controller.language,
              );
              if (!focusNode.hasFocus || options.isEmpty) return const Offstage();
              if (snapshot.hasData && snapshot.data != true && snapshot.data != null && '${snapshot.data}'.isNotEmpty) {
                isShowing = true;
                return panelWrap(codeFieldContext, wdg, focusNode, codeScroll, editorKey);
              } else {
                return const Offstage();
              }
            },
          );
        });

    panelOverlay = overlayEntry;

    Overlay.of(codeFieldContext).insert(panelOverlay!);
  }

  /// the core widget of tip panel.
  Widget buildPanel(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: options.map((tip) => itemBuilder(context, tip, current == options.indexOf(tip), write)).toList(),
      ),
    );
  }

  /// write the text to code field.
  void write(String text) {
    var offset = widget.controller.selection.baseOffset;
    int start = repeatCount(widget.controller.text.substring(0, offset), text);
    widget.controller
      ..text = widget.controller.text
          .replaceRange(widget.controller.selection.baseOffset - start, widget.controller.selection.baseOffset, text)
      ..selection = TextSelection.fromPosition(TextPosition(offset: offset + text.length - start));
    widget.onChanged?.call(widget.controller.text);
    hide();
  }

  /// write the current item text to code field.
  void writeCurrent() {
    if (options.isNotEmpty) {
      write(optionValue?.call(options[current]) ?? options[current].toString());
    }
  }

  /// get the repeat count of pre word and tip word.
  static int repeatCount(String text, String text2) {
    text = text.toLowerCase();
    text2 = text2.toLowerCase();
    var same = 0;
    while (text2.isNotEmpty) {
      if (text.endsWith(text2)) {
        return same += text2.length;
      }
      text2 = text2.substring(0, text2.length - 1);
    }
    return same;
  }

  Offset _editorOffset(ScrollController codeScroll, GlobalKey editorKey) {
    final box = editorKey.currentContext!.findRenderObject() as RenderBox?;
      var editorOffset = box?.localToGlobal(Offset.zero);
      if (editorOffset != null) {
        var fixedOffset =editorOffset;
        fixedOffset += Offset(0, codeScroll.offset);
        return fixedOffset;
      }
      return Offset.zero;
  }

  /// get the panel offset through the cursor offset.
  Offset cursorOffset(BuildContext context, CodeField widget, FocusNode focusNode, ScrollController codeScroll, GlobalKey editorKey) {
    var s = widget.controller.text;
    TextStyle textStyle = widget.textStyle ?? const TextStyle();
    textStyle = textStyle.copyWith(
      fontSize: textStyle.fontSize ?? 16.0,
    );
    TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        style: textStyle,
        text: s.substring(0, widget.controller.selection.baseOffset),
      ),
    )..layout();
    var cursorBefore = s.substring(0, widget.controller.selection.baseOffset);
    TextPainter hpainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        style: textStyle,
        text: cursorBefore.substring(max(cursorBefore.lastIndexOf('\n'), 0)),
      ),
    )..layout();

    final editorOffset = _editorOffset(codeScroll, editorKey);
    final caretOffset = _getCaretOffset(painter);
    print('editor offset ${editorOffset.dy}');
    print('painter height ${painter.height}');
    print('caret offset ${caretOffset.dy}');
    print('code scroll offset ${codeScroll.offset}');
    final f = max(codeScroll.offset, painter.height);
    final se = min(codeScroll.offset, painter.height);
    // final y =painter.height - caretOffset.dy + focusNode.offset.dy;
    final y =   f -se + focusNode.offset.dy;
    print('total offset ${y}');
    // bool flipVertical = _isVerticalFlipRequired(context, editorKey, editorOffset, Offset(0,y));
// print('flip vertical ${flipVertical}');
    print('-------------------------');
    return Offset(hpainter.width + focusNode.offset.dx, 0 );
  }

  Offset _getCaretOffset(TextPainter textPainter) {
    return textPainter.getOffsetForCaret(
      widget.controller.selection.base,
      Rect.zero,
    );
  }

  bool _isVerticalFlipRequired(BuildContext context, GlobalKey codeKey, Offset editorOffset, Offset normalOffset) {
    final viewInsets = EdgeInsets.fromViewPadding(View.of(context).viewInsets, View.of(context).devicePixelRatio);
    final windowHeight = MediaQuery.of(context).size.height - viewInsets.bottom - viewInsets.top;
    print('window height ${windowHeight}');
    print('max pop up height ${constraints.maxHeight}');
    // final isPopupShorterThanWindow =
    //     constraints.maxHeight < windowHeight;
    final isPopupOverflowingHeight = normalOffset.dy +
            constraints.maxHeight -
            (editorOffset.dy ?? 0) >
       windowHeight;

    return isPopupOverflowingHeight ;
  }

  /// the style widget of tip panel.
  Widget panelWrap(BuildContext context, CodeField wdg, FocusNode focusNode, ScrollController codeScroll, GlobalKey editorKey) {
    final offset = cursorOffset(context, widget, focusNode, codeScroll, editorKey);
    final viewInsets = EdgeInsets.fromViewPadding(View.of(context).viewInsets, View.of(context).devicePixelRatio);
    // final windowHeight = MediaQuery.of(context).size.height - viewInsets.bottom - viewInsets.top;
    // final pinToBottom = _pinToBottom(offset, context);
    final addedOffset = offsetFunc?.call() ?? Offset.zero;
    return Positioned(
      bottom: viewInsets.bottom + addedOffset.dy,
      // top:  offset.dy > viewInsets.bottom ? min(viewInsets.bottom, offset.dy - 300) : offset.dy,
      // top: !pinToBottom ? offset.dy : null,
      left: offset.dx + addedOffset.dx,
      child:   Material(
          child: StatefulBuilder(builder: (context, setState) {
            panelSetState = setState;
            return background(
              context,
              ConstrainedBox(
                constraints: constraints,
                child: buildPanel(context),
              ),
            );
          }),
        ),
    );
  }

  bool _pinToBottom(Offset offset, BuildContext context) {
    final viewInsets = EdgeInsets.fromViewPadding(View.of(context).viewInsets, View.of(context).devicePixelRatio);
    final screenSize = MediaQuery.of(context).size;
    final limit = screenSize.height - viewInsets.bottom - (offsetFunc?.call() ?? Offset.zero).dy;
    return offset.dy > limit;
  }

  /// the style widget of tip panel.
  Widget background(BuildContext context, Widget content) {
    return ColoredBox(color: Theme.of(context).colorScheme.secondaryContainer, child: content);
  }
}
