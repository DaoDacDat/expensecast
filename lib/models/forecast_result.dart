/// Value object ForecastResult (Figure 8).
class ForecastResult {
  final String category;
  final double predictedSpend;
  final double budgetLimit;

  /// predictedSpend / budgetLimit
  final double riskRatio;

  /// Chuỗi điểm dùng để vẽ đường "actual" trên biểu đồ Insights.
  final List<double> actualSeries;

  /// Chuỗi điểm dự báo tiếp nối actualSeries.
  final List<double> predictedSeries;

  const ForecastResult({
    required this.category,
    required this.predictedSpend,
    required this.budgetLimit,
    required this.riskRatio,
    this.actualSeries = const [],
    this.predictedSeries = const [],
  });

  bool get isAtRisk => riskRatio >= 1.0;
  bool get isWatch => riskRatio >= 0.9 && riskRatio < 1.0;

  RiskState get state {
    if (isAtRisk) return RiskState.atRisk;
    if (isWatch) return RiskState.watch;
    return RiskState.onTrack;
  }
}

enum RiskState {
  onTrack,
  watch,
  atRisk;

  String get label => switch (this) {
        RiskState.onTrack => 'on track',
        RiskState.watch => 'watch',
        RiskState.atRisk => 'at risk',
      };
}
