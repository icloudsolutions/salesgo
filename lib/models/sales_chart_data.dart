class SalesChartData {
  final String periodKey;
  final String agentName;
  final double amount;
  final int xIndex;

  SalesChartData({
    required this.periodKey,
    required this.agentName,
    required this.amount,
    required this.xIndex,
  });

  String get key => '${periodKey}_$agentName';
}