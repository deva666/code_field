import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:highlighting/highlighting.dart';

import '../../code_text_field.dart';

typedef OffsetGetter = Offset? Function();

class Completions {
  final List<Completion> completions;
  Completions({required this.completions});

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{}..addAll({'completions': completions.map((x) => x.toMap()).toList()});
    return result;
  }

  factory Completions.fromMap(Map<String, dynamic> map) {
    return Completions(
      completions: List<Completion>.from(map['completions']?.map((x) => Completion.fromMap(x))),
    );
  }

  String toJson() => json.encode(toMap());

  factory Completions.fromJson(String source) => Completions.fromMap(json.decode(source));
}

class Completion {
  final String name;
  final String complete;
  final String type;
  final String docstring;
  final String nameWithSymbols;

  Completion({required this.name, required this.complete, required this.type, required this.docstring, required this.nameWithSymbols});

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{}
      ..addAll({'name': name})
      ..addAll({'complete': complete})
      ..addAll({'type': type})
      ..addAll({'docstring': docstring})
      ..addAll({'nameWithSymbols': nameWithSymbols});

    return result;
  }

  factory Completion.fromMap(Map<String, dynamic> map) {
    return Completion(
      name: map['name'] ?? '',
      complete: map['complete'] ?? '',
      type: map['type'] ?? '',
      docstring: map['docstring'] ?? '',
      nameWithSymbols: map['nameWithSymbols'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory Completion.fromJson(String source) => Completion.fromMap(json.decode(source));
}

Widget defaultCompletionItemBuilder(Completion c, Function(Completion) onTap) => const SizedBox();

class CodeAutoComplete<T> {
  /// can input your options which created through editor text and language.
  List<T> Function(String, int cursorIndex, Mode?) optionsBuilder;

  /// depends on your options, you can create your own item widget.
  final Widget Function(T, bool, Function(String) onTap) itemBuilder;

  final Widget Function(Completion, Function(Completion) onTap) completionItemBuilder;

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
  OffsetGetter? initialOffset;
  Function(Offset) onOffsetUpdated;
  StreamController streamController;
  Stream get stream => streamController.stream;
  Stream<Completions>? completionsStream;

  Function()? showCallback;

  bool get active => panelOverlay != null;

  CodeAutoComplete(
      {required this.optionsBuilder,
      required this.itemBuilder,
      required this.streamController,
      required this.onOffsetUpdated,
      this.completionItemBuilder = defaultCompletionItemBuilder,
      this.initialOffset,
      this.constraints = const BoxConstraints(maxHeight: 300, maxWidth: 380),
      this.backgroundColor,
      this.optionValue,
      this.completionsStream});

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
  void show(BuildContext codeFieldContext, CodeField wdg, FocusNode focusNode, Function() callback) {
    widget = wdg;
    showCallback = callback;
    OverlayEntry overlayEntry =
        completionsStream == null ? buildSyncOverlayEntry(wdg, focusNode) : buildStreamOverlayEntry(wdg, focusNode);

    panelOverlay = overlayEntry;

    Overlay.of(codeFieldContext).insert(panelOverlay!);
  }

  OverlayEntry buildSyncOverlayEntry(CodeField wdg, FocusNode focusNode) {
    return OverlayEntry(builder: (context) {
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
            showCallback?.call();
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
  }

  // build from incoming stream of completions
  OverlayEntry buildStreamOverlayEntry(CodeField wdg, FocusNode focusNode) {
    return OverlayEntry(builder: (context) {
      return StreamBuilder<Completions?>(
        stream: completionsStream,
        builder: (context, snapshot) {
          isShowing = false;
          current = 0;
          if (!focusNode.hasFocus || snapshot.data == null || snapshot.data!.completions.isEmpty) return const Offstage();
          if (snapshot.hasData && snapshot.data is Completions && snapshot.data!.completions.isNotEmpty) {
            isShowing = true;
            showCallback?.call();
            return DraggableWidget(
              onOffsetUpdate: onOffsetUpdated,
              initialOffset: _getInitialOffset(context, widget, focusNode),
              child: panelWrap(context, wdg, focusNode, completions: snapshot.data),
            );
          } else {
            return const Offstage();
          }
        },
      );
    });
  }

  Widget buildCompletionsPanel(Completions completions) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            completions.completions.map((completion) => completionItemBuilder(completion, writeCompletion)).toList(),
      ),
    );
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
  void writeCompletion(Completion completion) {
    // var offset = widget.controller.selection.baseOffset;
    // int start = repeatCount(widget.controller.text.substring(0, offset), text);
    // widget.controller
    //   ..text = widget.controller.text
    //       .replaceRange(widget.controller.selection.baseOffset - start, widget.controller.selection.baseOffset, text)
    //   ..selection = TextSelection.fromPosition(TextPosition(offset: offset + text.length - start));
    widget.controller.insertStr(completion.complete);
    widget.onChanged?.call(widget.controller.text);
    hide();
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
    // return painter.getOffsetForCaret(widget.controller.selection.base, Rect.zero);
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
  Widget panelWrap(BuildContext context, CodeField wdg, FocusNode focusNode, {Completions? completions}) {
    return Material(
      type: MaterialType.transparency,
      child: background(
        context,
        ConstrainedBox(
          constraints: constraints,
          child: completions == null ? buildPanel() : buildCompletionsPanel(completions),
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
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: content,
        ));
  }
}

class DraggableWidget extends StatefulWidget {
  final Widget child;
  final Offset initialOffset;
  final Function(Offset) onOffsetUpdate;
  final Offset? extraBounds;

  const DraggableWidget({
    required this.child,
    required this.initialOffset,
    required this.onOffsetUpdate,
    this.extraBounds,
  });

  @override
  State<StatefulWidget> createState() => _DraggableWidgetState();
}

class _DraggableWidgetState extends State<DraggableWidget> {
  bool _isDragging = false;
  late Offset _offset;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
  }

  void _updatePosition(PointerMoveEvent pointerMoveEvent) {
    final size = MediaQuery.of(context).size;
    double newOffsetX =
        min(size.width - 44, max(0 + (widget.extraBounds?.dx ?? 0), _offset.dx + pointerMoveEvent.delta.dx));
    double newOffsetY =
        min(size.height - 160, max(0 + (widget.extraBounds?.dy ?? 0), _offset.dy + pointerMoveEvent.delta.dy));

    setState(() {
      _offset = Offset(newOffsetX, newOffsetY);
      widget.onOffsetUpdate(_offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: Listener(
        onPointerMove: (PointerMoveEvent pointerMoveEvent) {
          _updatePosition(pointerMoveEvent);

          setState(() {
            _isDragging = true;
          });
        },
        onPointerUp: (PointerUpEvent pointerUpEvent) {
          if (_isDragging) {
            setState(() {
              _isDragging = false;
            });
          } else {}
        },
        child: widget.child,
      ),
    );
  }
}
