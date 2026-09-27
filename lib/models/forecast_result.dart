/// Value object ForecastResult (Figure 8).
class ForecastResult {
  final String category;
  final double predictedSpend;
  final double budgetLimit;

  /// predictedSpend / budgetLimit
  final double riskRatio;

  /// Data points used to draw the "actual" line on the Insights chart.
  final List<double> actualSeries;

  /// Forecast data points continuing from actualSeries.
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
