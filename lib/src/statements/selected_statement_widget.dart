import 'package:flutter/material.dart';

class SelectedStatementWidget extends InheritedWidget {
  SelectedStatementWidget({required super.child});

  final ValueNotifier<String?> _statmentNotifier = ValueNotifier(null);

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }

  static void setCurrentStatement(BuildContext context, String? statement) {
    context.dependOnInheritedWidgetOfExactType<SelectedStatementWidget>()?._statmentNotifier.value = statement;
  }

  static String? getCurrentStatement(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SelectedStatementWidget>()?._statmentNotifier.value;
  }

  static void addListener(BuildContext context, VoidCallback listener) {
    context.dependOnInheritedWidgetOfExactType<SelectedStatementWidget>()?._statmentNotifier.addListener(listener);
  }

  static void removeListener(BuildContext context, VoidCallback listener) {
    context.dependOnInheritedWidgetOfExactType<SelectedStatementWidget>()?._statmentNotifier.removeListener(listener);
  }
}
