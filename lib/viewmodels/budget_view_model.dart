import 'package:flutter/foundation.dart';

import '../core/categories.dart';
import '../models/budget.dart';

/// BudgetViewModel (Figure 8) - manages limits per category and period.
class BudgetViewModel extends ChangeNotifier {
  BudgetViewModel() {
    _seed();
  }

  final List<Budget> _budgets = [];
  BudgetPeriod _period = BudgetPeriod.monthly;

  List<Budget> get budgets => List.unmodifiable(_budgets);
  BudgetPeriod get period => _period;

  double get totalLimit => _budgets.fold<double>(0, (s, b) => s + b.limit);

  Budget? byCategory(String category) {
    for (final b in _budgets) {
      if (b.category == category) return b;
    }
    return null;
  }

  double limitFor(String category) => byCategory(category)?.limit ?? 0;

  void setPeriod(BudgetPeriod p) {
    _period = p;
    for (var i = 0; i < _budgets.length; i++) {
      _budgets[i] = _budgets[i].copyWith(period: p);
    }
    notifyListeners();
  }

  void updateBudget(Budget budget) {
    final i = _budgets.indexWhere((b) => b.category == budget.category);
    if (i == -1) {
      _budgets.add(budget);
    } else {
      _budgets[i] = budget;
    }
    notifyListeners();
  }

  void removeBudget(String category) {
    _budgets.removeWhere((b) => b.category == category);
    notifyListeners();
  }

  /// Categories without a budget yet - used by the "+ Add category budget" button.
  List<String> get availableCategories => Categories.all
      .where((c) => _budgets.every((b) => b.category != c))
      .toList();

  void _seed() {
    _budgets.addAll(const [
      Budget(category: Categories.groceries, limit: 400),
      Budget(category: Categories.transport, limit: 200),
      Budget(category: Categories.eatingOut, limit: 150),
      Budget(category: Categories.utilities, limit: 180),
      Budget(category: Categories.other, limit: 70),
    ]);
  }
}
