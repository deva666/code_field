abstract class CodeAnalysis {
  int get lineNumber;
  int get column;
  String get text;
}

class ErrorAnalysis implements CodeAnalysis {
  @override
  final int lineNumber;
  @override
  final int column;
  @override
  final String text;

  ErrorAnalysis(this.lineNumber, this.column, this.text);
}
