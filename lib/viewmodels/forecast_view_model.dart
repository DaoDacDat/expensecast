import 'package:flutter/foundation.dart';

import '../models/budget.dart';
import '../models/forecast_method.dart';
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
  ForecastMethod _method = ForecastMethod.gru;
  ForecastHorizon _horizon = ForecastHorizon.month;

  List<ForecastResult> get results => List.unmodifiable(_results);
  bool get isBusy => _isBusy;
  DateTime? get computedAt => _computedAt;

  /// Method the user selected (results may fall back, see [fallbackReason]).
  ForecastMethod get method => _method;

  /// Set when the selected method could not be used for some categories.
  String? get fallbackReason {
    for (final r in _results) {
      if (r.fallbackReason != null) return r.fallbackReason;
    }
    return null;
  }

  /// Chooses the method for the next run; does not run the forecast itself.
  void setMethod(ForecastMethod method) {
    if (method == _method) return;
    _method = method;
    notifyListeners();
  }

  ForecastHorizon get horizon => _horizon;

  /// Chooses the horizon for the next run; does not run the forecast itself.
  void setHorizon(ForecastHorizon horizon) {
    if (horizon == _horizon) return;
    _horizon = horizon;
    notifyListeners();
  }

  bool get hasRun => _computedAt != null;

  String? _selectedCategory;

  /// Result shown in the chart: the category the user tapped, or the riskiest
  /// one (first) by default.
  ForecastResult? get selected {
    if (_results.isEmpty) return null;
    for (final r in _results) {
      if (r.category == _selectedCategory) return r;
    }
    return _results.first;
  }

  void selectCategory(String category) {
    if (category == _selectedCategory) return;
    _selectedCategory = category;
    notifyListeners();
  }

  List<ForecastResult> get atRisk => _results.where((r) => r.isAtRisk).toList();

  /// Runs the forecast. Called only when the user taps "Run forecast".
  Future<void> refreshForecast(
    List<Transaction> transactions,
    List<Budget> budgets,
  ) async {
    _isBusy = true;
    notifyListeners();

    _results = await _service.predict(transactions, budgets,
        method: _method, horizon: _horizon);
    _computedAt = DateTime.now();
    _isBusy = false;
    notifyListeners();
  }
}
