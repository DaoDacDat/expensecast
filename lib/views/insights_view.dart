import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../viewmodels/budget_view_model.dart';
import '../viewmodels/forecast_view_model.dart';
import '../viewmodels/transaction_view_model.dart';
import '../widgets/forecast_chart.dart';
import '../widgets/risk_card.dart';

/// Mockup 6: Insights & Forecast.
///
/// This screen deliberately limits raw data: one trajectory chart against
/// the limit, then each category is condensed into a single risk status (section 5.4).
class InsightsView extends StatelessWidget {
  const InsightsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forecast = context.watch<ForecastViewModel>();
    final tx = context.watch<TransactionViewModel>();
    final budgets = context.watch<BudgetViewModel>();

    final results = forecast.results;
    final headline = results.isEmpty ? null : results.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights & Forecast'),
        actions: [
          IconButton(
            tooltip: 'Recompute forecast',
            icon: const Icon(Icons.refresh),
            onPressed: forecast.isBusy
                ? null
                : () => forecast.refreshForecast(
                      tx.transactions,
                      budgets.budgets,
                    ),
          ),
        ],
      ),
      body: forecast.isBusy && results.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Next 30 days, predicted',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                    child: headline == null
                        ? const SizedBox(
                            height: 120,
                            child: Center(
                              child: Text('Not enough data yet.'),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headline.category,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ForecastChart(
                                actual: headline.actualSeries,
                                predicted: headline.predictedSeries,
                                budgetLimit: headline.budgetLimit,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'By category',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                for (final r in results) ...[
                  RiskCard(result: r),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    forecast.computedAt == null
                        ? 'Forecast computed on this device'
                        : 'Forecast computed on this device · '
                            'updated ${Fmt.relative(forecast.computedAt!)}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
