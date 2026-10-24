/// Forecasting method the user can choose on the Insights screen.
enum ForecastMethod {
  gru,
  movingAverage;

  String get label => switch (this) {
        ForecastMethod.gru => 'GRU model',
        ForecastMethod.movingAverage => 'Moving average',
      };
}

/// How far ahead the forecast looks.
enum ForecastHorizon {
  week(7),
  month(30);

  const ForecastHorizon(this.days);

  final int days;

  String get label => '$days days';
}
