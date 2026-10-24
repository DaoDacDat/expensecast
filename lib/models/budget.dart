/// Budget period - the BudgetPeriod enum in the class diagram.
enum BudgetPeriod {
  weekly,
  fortnightly,
  monthly;

  /// Length of the period in days (a month is treated as 30 days).
  int get days => switch (this) {
        BudgetPeriod.weekly => 7,
        BudgetPeriod.fortnightly => 14,
        BudgetPeriod.monthly => 30,
      };

  String get label => switch (this) {
        BudgetPeriod.weekly => 'Weekly',
        BudgetPeriod.fortnightly => 'Fortnightly',
        BudgetPeriod.monthly => 'Monthly',
      };
}

/// Entity Budget (Figure 8).
class Budget {
  final String category;
  final double limit;
  final BudgetPeriod period;

  const Budget({
    required this.category,
    required this.limit,
    this.period = BudgetPeriod.monthly,
  });

  bool isExceeded(double spent) => spent > limit;

  Budget copyWith({String? category, double? limit, BudgetPeriod? period}) =>
      Budget(
        category: category ?? this.category,
        limit: limit ?? this.limit,
        period: period ?? this.period,
      );

  Map<String, Object?> toMap() => {
        'category': category,
        'limit': limit,
        'period': period.name,
      };
}
