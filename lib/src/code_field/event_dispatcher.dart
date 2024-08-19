import 'package:flutter/material.dart';

abstract class CodeFieldEvent {}

class ClearCodeErrorsEvent extends CodeFieldEvent {}

class CodeEventNotifier {
  final _listenables = <Function(CodeFieldEvent)>[];
  void addListener(Function(CodeFieldEvent) listener) {
    _listenables.add(listener);
  }

  void removeListener(Function(CodeFieldEvent) listener) {
    _listenables.remove(listener);
  }

  void notifyListeners(CodeFieldEvent event) {
    for (final l in _listenables) {
      l.call(event);
    }
  }
}

class CodeFieldEventDispatcher extends InheritedWidget {
  CodeFieldEventDispatcher({required super.child});

  // ignore: close_sinks
  final CodeEventNotifier notifier = CodeEventNotifier();

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }

  static void addEvent(BuildContext context, CodeFieldEvent event) {
    context.dependOnInheritedWidgetOfExactType<CodeFieldEventDispatcher>()?.notifier.notifyListeners(event);
  }

  void addListener(Function(CodeFieldEvent) listener) {
    notifier.addListener(listener);
  }

  void removeListener(Function(CodeFieldEvent) listener) {
    notifier.removeListener(listener);
  }

  static CodeFieldEventDispatcher? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CodeFieldEventDispatcher>();
  }
}
