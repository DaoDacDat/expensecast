import 'dart:math' as math;

import 'package:expensecast/core/categories.dart';
import 'package:expensecast/models/budget.dart';
import 'package:expensecast/models/forecast_method.dart';
import 'package:expensecast/models/transaction.dart';
import 'package:expensecast/services/forecast_service.dart';
import 'package:expensecast/services/gru_forecaster.dart';
import 'package:expensecast/services/ocr_service.dart';
import 'package:expensecast/viewmodels/transaction_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGru implements GruRunner {
  @override
  double get countScale => 2;

  int calls = 0;
  List<List<double>>? history;
  List<List<double>>? calendar;
  List<double>? category;

  @override
  Future<List<double>> run({
    required List<List<double>> history,
    required List<List<double>> futureCalendar,
    required List<double> category,
  }) async {
    calls++;
    this.history = history;
    calendar = futureCalendar;
    this.category = category;
    return List<double>.filled(7, 10);
  }
}

Transaction _tx(int daysAgo, double amount, String category) => Transaction(
      id: '$daysAgo-$amount',
      merchant: 'm',
      amount: amount,
      category: category,
      timestamp: DateTime.now().subtract(Duration(days: daysAgo)),
      source: TxSource.manualEntry,
    );

void main() {
  const budgets = [
    Budget(category: Categories.food, limit: 100),
  ];

  test(
      'GRU gets [60,7] / [7,5] / [3] tensors when there are 60 days of history',
      () async {
    final gru = _FakeGru();
    final txs = [_tx(70, 5, Categories.food), _tx(1, 20, Categories.food)];

    final r = (await ForecastEngine(gru: gru)
            .predict(txs, budgets, method: ForecastMethod.gru))
        .single;

    expect(gru.calls, 1);
    expect(gru.history!.length, 60);
    expect(gru.history!.first.length, 7);
    expect(gru.calendar!.length, 7);
    expect(gru.calendar!.first.length, 5);
    expect(gru.category, [1, 0, 0]);
    expect(r.method, ForecastMethod.gru);
    // Fake output 10 (scaled) x scale 20 (mean of active days) x 30 days.
    expect(r.predictedSpend, closeTo(6000, 1e-9));
    expect(gru.history!.last[0], 0, reason: 'today has no spend');
    expect(gru.history![58][0], closeTo(1, 1e-9), reason: 'amount / scale');
    expect(gru.history![58][1], closeTo(math.log(2) / 2, 1e-9));
    expect(r.fallbackReason, isNull);
  });

  test('falls back to moving average with fewer than 60 days of history',
      () async {
    final gru = _FakeGru();
    final txs = [_tx(10, 70, Categories.food)];

    final r = (await ForecastEngine(gru: gru)
            .predict(txs, budgets, method: ForecastMethod.gru))
        .single;

    expect(gru.calls, 0);
    expect(r.method, ForecastMethod.movingAverage);
    expect(r.fallbackReason, contains('11/60'));
  });

  test('moving average uses the mean of the last 7 days', () async {
    final txs = [_tx(0, 70, Categories.food), _tx(80, 1, Categories.food)];

    final r = (await ForecastEngine(gru: _FakeGru())
            .predict(txs, budgets, method: ForecastMethod.movingAverage))
        .single;

    expect(r.predictedSpend, closeTo(70 / 7 * 30, 1e-9));
    expect(r.fallbackReason, isNull);
  });

  test('7-day horizon forecasts 7 days against a pro-rated limit', () async {
    final txs = [_tx(0, 70, Categories.food), _tx(80, 1, Categories.food)];

    final r = (await ForecastEngine(gru: _FakeGru()).predict(
      txs,
      budgets,
      method: ForecastMethod.movingAverage,
      horizon: ForecastHorizon.week,
    ))
        .single;

    expect(r.horizonDays, 7);
    expect(r.predictedSpend, closeTo(70, 1e-9));
    expect(r.budgetLimit, closeTo(100 / 30 * 7, 1e-9));
    expect(r.actualSeries.last, closeTo(70, 1e-9));
  });

  test('calendar features follow the training definition', () {
    // Monday 5 Jan 2026: dow 0, day 5 of 31, day-of-year 5 of 365.
    final f = calendarFeatures(DateTime(2026, 1, 5));
    expect(f.length, 5);
    expect(f[0], closeTo(0, 1e-9));
    expect(f[1], closeTo(1, 1e-9));
    expect(f[2], closeTo(4 / 30, 1e-9));
    expect(f[3], closeTo(math.sin(2 * math.pi * 4 / 365), 1e-9));
    expect(f[4], closeTo(math.cos(2 * math.pi * 4 / 365), 1e-9));
    // Leap year uses a 366-day cycle.
    expect(calendarFeatures(DateTime(2028, 12, 31))[3],
        closeTo(math.sin(2 * math.pi * 365 / 366), 1e-9));
  });

  test('seed data has 60 days of history so the GRU can run', () async {
    final vm = TransactionViewModel(ocrService: StubOcrService());
    final gru = _FakeGru();
    final all = [
      for (final c in Categories.all) Budget(category: c, limit: 100),
    ];

    final results = await ForecastEngine(gru: gru)
        .predict(vm.transactions, all, method: ForecastMethod.gru);

    expect(gru.calls, Categories.all.length);
    expect(results.every((r) => r.method == ForecastMethod.gru), isTrue);
  });
}
