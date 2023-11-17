import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:highlighting/highlighting.dart';
import '../../code_text_field.dart';

class CodeSnippet {
  final String snippetId;
  final String title;
  final String snippet;
  final int offsetSelection;
  final int selectionLength;
  final int offsetLine;
  final bool startsOnNewLine;

  CodeSnippet(
      {required this.snippetId,
      required this.title,
      required this.snippet,
      required this.offsetSelection,
      required this.offsetLine,
      this.startsOnNewLine = true,
      this.selectionLength = 0});
}

class CodeSnippetSelector {
  /// can input your options which created through editor text and language.
  List<CodeSnippet> Function(String s, int cursorIndex, Mode?) optionsBuilder;

  /// depends on your options, you can create your own item widget.
  final Widget Function(CodeSnippet, bool, Function(CodeSnippet) onTap) itemBuilder;

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

  void Function()? showListener;

  /// the code field widget.
  late CodeField widget;

  /// the options list.
  List<CodeSnippet> options = [];

  /// the panel offset.
  OffsetGetter? initialOffset;
  Function(Offset) onOffsetUpdated;
  StreamController streamController;
  Stream get stream => streamController.stream;

  bool get active => panelOverlay != null;

  CodeSnippetSelector({
    required this.streamController,
    required this.optionsBuilder,
    required this.itemBuilder,
    // required this.streamController,
    required this.onOffsetUpdated,
    this.initialOffset,
    this.constraints = const BoxConstraints(maxHeight: 300, maxWidth: 240),
    this.backgroundColor,
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
  void show(BuildContext codeFieldContext, CodeField wdg, FocusNode focusNode, Function() showCallback) {
    widget = wdg;
    showListener = showCallback;
    OverlayEntry overlayEntry = OverlayEntry(builder: (context) {
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
            showListener?.call();
            return DraggableWidget(
              onOffsetUpdate: onOffsetUpdated,
              initialOffset: _getInitialOffset(context, widget, focusNode),
              child: panelWrap(context, wdg, focusNode),
            );
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
  Widget buildPanel() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: options.map((tip) => itemBuilder(tip, current == options.indexOf(tip), write)).toList(),
      ),
    );
  }

  /// write the text to code field.
  void write(CodeSnippet snippet) {
    final offsetBefore = widget.controller.selection.baseOffset;
    final indentCount = getIndentCount();
    final isCurrentLineEmpty = isLineEmpty();
    final snippetText = isCurrentLineEmpty ? snippet.snippet : '\n${snippet.snippet}';
    final snippetLines = snippetText.split('\n');
    final indentedLines = <String>[];
    final offsetLine = isCurrentLineEmpty ? snippet.offsetLine : snippet.offsetLine + 1;
    var addedOffset = isCurrentLineEmpty ? 0 : 1;
    for (var i = 0; i < snippetLines.length; i++) {
      if (i == 0) {
        indentedLines.add(snippetLines[i]);
      } else {
        indentedLines.add("{' ' * indentCount}${snippetLines[i]}");
        if (i <= offsetLine) {
          addedOffset += indentCount;
        }
      }
    }
    final indentedSnippet = snippetLines.mapIndexed((i, e) => i == 0 ? e : "${' ' * indentCount}$e").join('\n');
    widget.controller.insertStr(indentedSnippet);
    final newOffset = offsetBefore + snippet.offsetSelection + addedOffset;
    widget.controller.selection =
        TextSelection(baseOffset: newOffset, extentOffset: newOffset + snippet.selectionLength);
    widget.onChanged?.call(widget.controller.text);
    hide();
  }

  int getIndentCount() {
    final offset = widget.controller.selection.baseOffset;
    final lineStart = widget.controller.lineStart(offset);
    final lineEnd = widget.controller.lineEnd(offset);
    var current = lineStart;
    var count = 0;
    while (current < lineEnd && widget.controller.text[current] == ' ') {
      current++;
      count++;
    }
    return count;
  }

  bool isLineEmpty() {
    final offset = widget.controller.selection.baseOffset;
    final lineStart = widget.controller.lineStart(offset);
    final lineEnd = widget.controller.lineEnd(offset);
    return !RegExp(r'[^\s\\]').hasMatch(widget.controller.text.substring(lineStart, lineEnd));
  }

  Offset _getInitialOffset(BuildContext context, CodeField widget, FocusNode focusNode) {
    final inital = initialOffset?.call();
    if (inital != null) {
      return inital;
    }
    final offset = cursorOffset(context, widget, focusNode);
    final pinToBottom = _pinToBottom(offset, context);
    if (pinToBottom) {
      return Offset(offset.dx,
          EdgeInsets.fromViewPadding(View.of(context).viewInsets, View.of(context).devicePixelRatio).bottom + 64);
    } else {
      return offset;
    }
  }

  /// get the panel offset through the cursor offset.
  Offset cursorOffset(BuildContext context, CodeField widget, FocusNode focusNode) {
    var text = widget.controller.text;
    var s =
        widget.controller.selection.baseOffset < 0 ? text : text.substring(0, widget.controller.selection.baseOffset);

    TextStyle textStyle = widget.textStyle ?? const TextStyle();
    textStyle = textStyle.copyWith(
      fontSize: textStyle.fontSize ?? 16.0,
    );
    TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(style: textStyle, text: text),
    )..layout();

    var cursorBefore = s.substring(0, widget.controller.selection.baseOffset);
    TextPainter hpainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        style: textStyle,
        text: cursorBefore.substring(max(cursorBefore.lastIndexOf('\n'), 0)),
      ),
    )..layout();

    return Offset(hpainter.width + focusNode.offset.dx + 16, painter.height + focusNode.offset.dy);
  }

  /// the style widget of tip panel.
  Widget panelWrap(BuildContext context, CodeField wdg, FocusNode focusNode) {
    return Material(
      type: MaterialType.transparency,
      child: background(
        context,
        ConstrainedBox(
          constraints: constraints,
          child: buildPanel(),
        ),
      ),
    );
  }

  bool _pinToBottom(Offset offset, BuildContext context) {
    final viewInsets = EdgeInsets.fromViewPadding(View.of(context).viewInsets, View.of(context).devicePixelRatio);
    final screenSize = MediaQuery.of(context).size;
    final limit = screenSize.height - viewInsets.bottom;
    return offset.dy > limit;
  }

  /// the style widget of tip panel.
  Widget background(BuildContext context, Widget content) {
    return DecoratedBox(
      decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: content,
      ),
    );
  }
}

extension IterableExt<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(int index, T element) convert) sync* {
    var index = 0;
    for (var element in this) {
      yield convert(index++, element);
    }
  }
}
