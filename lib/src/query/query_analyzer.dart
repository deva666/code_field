abstract class QueryAnalyzer {
  Future<List<StatementPosition>> statementPositionsAsync(String sql);
  Future<String?> analyzeSql(String sql);
}

class StatementPosition {
  final int start;
  final int len;

  StatementPosition({required this.start, required this.len});
}
