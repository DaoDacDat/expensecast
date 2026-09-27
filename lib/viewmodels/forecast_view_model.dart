import 'package:flutter/foundation.dart';

import '../models/budget.dart';
import '../models/forecast_result.dart';
import '../models/transaction.dart';
import '../services/forecast_service.dart';

/// ForecastViewModel (Figure 8) - depends only on the [ForecastService]
/// interface so it can be replaced with a stub in unit tests (section 7.3).
class ForecastViewModel extends ChangeNotifier {
  ForecastViewModel({required ForecastService service}) : _service = service;

  final ForecastService _service;

  List<ForecastResult> _results = [];
  bool _isBusy = false;
  DateTime? _computedAt;

  List<ForecastResult> get results => List.unmodifiable(_results);
  bool get isBusy => _isBusy;
  DateTime? get computedAt => _computedAt;

  List<ForecastResult> get atRisk =>
      _results.where((r) => r.isAtRisk).toList();

  Future<void> refreshForecast(
    List<Transaction> transactions,
    List<Budget> budgets,
  ) async {
    _isBusy = true;
    notifyListeners();

    _results = await _service.predict(transactions, budgets);
    _computedAt = DateTime.now();
    _isBusy = false;
    notifyListeners();
  }
}
