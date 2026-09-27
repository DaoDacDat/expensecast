import '../models/budget.dart';
import '../models/forecast_result.dart';
import '../models/transaction.dart';

/// IForecastService (Figure 8). Sprint 3 sẽ có cài đặt ForecastEngine
/// chạy TensorFlow Lite; ở đây dùng bản heuristic để UI có số liệu thật
/// từ dữ liệu giao dịch hiện có.
abstract class ForecastService {
  Future<List<ForecastResult>> predict(
    List<Transaction> transactions,
    List<Budget> budgets,
  );
}

/// Bản dự báo tuyến tính đơn giản: lấy tốc độ chi tiêu trung bình mỗi ngày
/// trong 30 ngày gần nhất rồi ngoại suy cho 30 ngày tới.
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

  /// Chi tiêu cộng dồn theo từng mốc thời gian, dùng vẽ đường liền "actual".
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

  /// Đường đứt nét "predicted" nối tiếp từ mức chi tiêu hiện tại.
  List<double> _projection(double spent, double predicted,
      {required int points}) {
    final step = (predicted - spent) / points;
    return List<double>.generate(points, (i) => spent + step * (i + 1));
  }
}
