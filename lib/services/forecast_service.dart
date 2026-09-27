import '../models/budget.dart';
import '../models/forecast_result.dart';
import '../models/transaction.dart';

/// IForecastService (Figure 8). Sprint 3 will add a ForecastEngine implementation
/// running TensorFlow Lite; a heuristic version is used here so the UI shows real
/// numbers from the existing transaction data.
abstract class ForecastService {
  Future<List<ForecastResult>> predict(
    List<Transaction> transactions,
    List<Budget> budgets,
  );
}

/// Simple linear forecast: takes the average daily spending rate
/// over the last 30 days and extrapolates it over the next 30 days.
class HeuristicForecastService implements ForecastService {
  @override
  Future<List<ForecastResult>> predict(
    List<Transaction> transactions,
    List<Budget> budgets,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: 30));

    final results = <ForecastResult>[];
    for (final budget in budgets) {
      final inWindow = transactions
          .where((t) =>
              t.category == budget.category && t.timestamp.isAfter(windowStart))
          .toList();

      final spent = inWindow.fold<double>(0, (sum, t) => sum + t.amount);
      final elapsedDays = now.day.clamp(1, 30);
      final dailyRate = spent / elapsedDays;
      final predicted = dailyRate * 30;

      results.add(
        ForecastResult(
          category: budget.category,
          predictedSpend: predicted,
          budgetLimit: budget.limit,
          riskRatio: budget.limit == 0 ? 0 : predicted / budget.limit,
          actualSeries: _cumulativeSeries(inWindow, now, points: 6),
          predictedSeries: _projection(spent, predicted, points: 5),
        ),
      );
    }

    results.sort((a, b) => b.riskRatio.compareTo(a.riskRatio));
    return results;
  }

  /// Cumulative spending at each time point, used to draw the solid "actual" line.
  List<double> _cumulativeSeries(
    List<Transaction> txs,
    DateTime now, {
    required int points,
  }) {
    if (txs.isEmpty) return List<double>.filled(points, 0);
    final start = now.subtract(const Duration(days: 30));
    final buckets = List<double>.filled(points, 0);
    for (final t in txs) {
      final ratio = t.timestamp.difference(start).inMinutes / (30 * 24 * 60);
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
