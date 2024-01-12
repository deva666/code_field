abstract class QueryAnalyzer {
  List<StatementPosition> statementPositions(String sql);
  Future<List<StatementPosition>> statementPositionsAsync(String sql);
}

class StatementPosition {
  final int start;
  final int len;

  StatementPosition({required this.start, required this.len});
}
