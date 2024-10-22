import 'package:flutter/foundation.dart';

abstract class CodeAnalysis {
  int get lineNumber;
  int get column;
  String get text;
  int? get baseOffset;
  int? get offsetLength;
}

@immutable
class ErrorAnalysis implements CodeAnalysis {
  @override
  final int lineNumber;
  @override
  final int column;
  @override
  final String text;
  @override
  final int? baseOffset;
  @override
  final int? offsetLength;

  const ErrorAnalysis(this.lineNumber, this.column, this.text, {this.baseOffset, this.offsetLength});

  @override
    String toString() {
      return '$lineNumber:$column $text';
    }
  
  @override
    bool operator ==(Object other) {
      if (other is ErrorAnalysis ) {
        return other.lineNumber == lineNumber;
      }
      return false;
    }

  @override
    int get hashCode => lineNumber.hashCode;
}
