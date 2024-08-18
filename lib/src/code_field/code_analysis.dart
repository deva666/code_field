abstract class CodeAnalysis {
  int get lineNumber;
  String get text;
}

class ErrorAnalysis implements CodeAnalysis {
  @override
  final int lineNumber;
  @override
  final String text;

  ErrorAnalysis(this.lineNumber, this.text);
}
