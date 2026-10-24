import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/budget.dart';
import '../models/forecast_method.dart';
import '../models/forecast_result.dart';
import '../models/transaction.dart';
import 'gru_forecaster.dart';

/// IForecastService (Figure 8). Implementations turn transaction history into
/// a per-category [ForecastResult] using the requested [ForecastMethod].
abstract class ForecastService {
  Future<List<ForecastResult>> predict(
    List<Transaction> transactions,
    List<Budget> budgets, {
    ForecastMethod method = ForecastMethod.gru,
    ForecastHorizon horizon = ForecastHorizon.month,
  });
}

/// ForecastEngine: runs the on-device GRU (.tflite) model when there is enough
/// history, otherwise (or on user choice) a moving average.
class ForecastEngine implements ForecastService {
  ForecastEngine({GruRunner? gru}) : _gru = gru ?? TfliteGruRunner();

  final GruRunner _gru;

  /// Days averaged by the moving-average method.
  static const movingAverageWindow = 7;

  @override
  Future<List<ForecastResult>> predict(
    List<Transaction> transactions,
    List<Budget> budgets, {
    ForecastMethod method = ForecastMethod.gru,
    ForecastHorizon horizon = ForecastHorizon.month,
  }) async {
    final today = _dayOf(DateTime.now());
    final historyDays = _historyDays(transactions, today);

    _log('--- forecast run: method=${method.name} horizon=${horizon.days}d '
        'history=$historyDays days, ${transactions.length} transactions ---');

    final results = <ForecastResult>[];
    for (final budget in budgets) {
      final txs =
          transactions.where((t) => t.category == budget.category).toList();
      final daily = _dailyTotals(txs, today, GruSpec.historyDays);
      final counts = _dailyCounts(txs, today, GruSpec.historyDays);

      var used = method;
      String? reason;
      List<double>? forecast;

      if (method == ForecastMethod.gru) {
        reason = _gruBlocker(historyDays, budget.category);
        if (reason == null) {
          try {
            forecast = await _runGru(budget.category, daily, counts, today);
          } catch (e) {
            reason = 'GRU model unavailable ($e)';
          }
        }
        if (forecast == null) used = ForecastMethod.movingAverage;
      }
      forecast ??= _movingAverage(daily);

      // The model forecasts 7 days; longer horizons repeat its mean daily spend.
      final days = horizon.days;
      final meanDaily =
          forecast.fold<double>(0, (a, b) => a + b) / forecast.length;
      final predicted = meanDaily * days;
      final spent =
          _dailyTotals(txs, today, days).fold<double>(0, (a, b) => a + b);
      // Budgets are per period (e.g. monthly), so pro-rate to the horizon.
      final limit = budget.limit / budget.period.days * days;

      _log(
        '${budget.category}: requested=${method.name} used=${used.name}'
        '${reason == null ? '' : ' (fallback: $reason)'}\n'
        '  daily forecast (next ${forecast.length}d): ${_fmt(forecast)}\n'
        '  ${horizon.days}d predicted=${predicted.toStringAsFixed(2)} '
        'limit=${limit.toStringAsFixed(2)} '
        'risk=${limit == 0 ? 0 : (predicted / limit).toStringAsFixed(2)}',
      );

      results.add(
        ForecastResult(
          category: budget.category,
          predictedSpend: predicted,
          budgetLimit: limit,
          riskRatio: limit == 0 ? 0 : predicted / limit,
          actualSeries: _cumulativeSeries(txs, DateTime.now(), days, points: 6),
          predictedSeries: _projection(spent, predicted, points: 5),
          method: used,
          fallbackReason: reason,
          horizonDays: days,
        ),
      );
    }

    results.sort((a, b) => b.riskRatio.compareTo(a.riskRatio));
    return results;
  }

  /// Why the GRU cannot be used for this category, or null if it can.
  String? _gruBlocker(int historyDays, String category) {
    if (historyDays < GruSpec.historyDays) {
      return 'Not enough history ($historyDays/${GruSpec.historyDays} days)';
    }
    if (!GruSpec.categories.contains(category)) {
      return 'GRU model does not cover "$category"';
    }
    return null;
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[ExpenseCast] $message');
  }

  static String _fmt(List<double> v, [int digits = 2]) =>
      '[${v.map((e) => e.toStringAsFixed(digits)).join(', ')}]';

  /// Builds the three input tensors exactly as in training and runs the GRU.
  ///
  /// Amounts are divided by the mean spend on active days of this category's
  /// own 60-day history (the training notebook's scaling rule, refitted on the
  /// user's data so the currency does not matter), and the output is
  /// multiplied back by the same scale.
  Future<List<double>> _runGru(
    String category,
    List<double> daily,
    List<double> counts,
    DateTime today,
  ) async {
    final active = daily.where((v) => v > 0).toList();
    final scale = active.isEmpty
        ? 1.0
        : math.max(1.0, active.reduce((a, b) => a + b) / active.length);
    final inputs = buildGruInputs(
      category: category,
      daily: daily,
      counts: counts,
      lastDay: today,
      moneyScale: scale,
      countScale: _gru.countScale,
    );

    _log('$category: GRU input scale=${scale.toStringAsFixed(2)} '
        'countScale=${_gru.countScale.toStringAsFixed(4)} '
        'activeDays=${active.length}/${daily.length}');

    final out = await _gru.run(
      history: inputs.history,
      futureCalendar: inputs.futureCalendar,
      category: inputs.category,
    );
    _log('$category: GRU raw output (scaled): ${_fmt(out, 4)}');
    return out.map((v) => v < 0 ? 0.0 : v * scale).toList();
  }

  /// Flat forecast: the mean of the last [movingAverageWindow] days.
  List<double> _movingAverage(List<double> daily) {
    final recent = daily.sublist(daily.length - movingAverageWindow);
    final mean = recent.fold<double>(0, (a, b) => a + b) / recent.length;
    return List<double>.filled(GruSpec.horizonDays, mean);
  }

  /// Days covered by the user's data, from the first transaction to today.
  int _historyDays(List<Transaction> txs, DateTime today) {
    if (txs.isEmpty) return 0;
    final first = txs
        .map((t) => _dayOf(t.timestamp))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return _daysBetween(first, today) + 1;
  }

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Moves a date by whole calendar days (not 24h blocks, which break on
  /// daylight-saving changes).
  static DateTime _shiftDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// Whole calendar days from [a] to [b]; unaffected by daylight-saving
  /// changes (a local day can be 23 or 25 hours long).
  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  /// Spend per day for the last [days] days, oldest first, ending today.
  List<double> _dailyTotals(List<Transaction> txs, DateTime today, int days) {
    final out = List<double>.filled(days, 0);
    final first = _shiftDays(today, -(days - 1));
    for (final t in txs) {
      final i = _daysBetween(first, t.timestamp);
      if (i >= 0 && i < days) out[i] += t.amount;
    }
    return out;
  }

  List<double> _dailyCounts(List<Transaction> txs, DateTime today, int days) {
    final out = List<double>.filled(days, 0);
    final first = _shiftDays(today, -(days - 1));
    for (final t in txs) {
      final i = _daysBetween(first, t.timestamp);
      if (i >= 0 && i < days) out[i] += 1;
    }
    return out;
  }

  /// Cumulative spending at each time point, used to draw the solid "actual" line.
  List<double> _cumulativeSeries(
    List<Transaction> txs,
    DateTime now,
    int days, {
    required int points,
  }) {
    final start = now.subtract(Duration(days: days));
    final inWindow = txs.where((t) => t.timestamp.isAfter(start)).toList();
    if (inWindow.isEmpty) return List<double>.filled(points, 0);
    final buckets = List<double>.filled(points, 0);
    for (final t in inWindow) {
      final ratio = t.timestamp.difference(start).inMinutes / (days * 24 * 60);
      final index = (ratio * points).floor().clamp(0, points - 1);
      buckets[index] += t.amount;
    }
    var running = 0.0;
    return buckets.map((v) => running += v).toList();
  }

  /// Dashed "predicted" line continuing from the current spending level.
  List<double> _projection(double spent, double predicted,
      {required int points}) {
    final step = (predicted - spent) / points;
    return List<double>.generate(points, (i) => spent + step * (i + 1));
  }
}
