import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../viewmodels/budget_view_model.dart';
import '../viewmodels/forecast_view_model.dart';
import '../viewmodels/transaction_view_model.dart';
import '../widgets/transaction_tile.dart';
import 'capture_view.dart';
import 'history_view.dart';
import 'manual_transaction_view.dart';

/// Mockup 2: Home - spending balance, budget progress, recent transactions.
class HomeView extends StatelessWidget {
  const HomeView({super.key, this.onSeeInsights});

  final VoidCallback? onSeeInsights;

  Future<void> _openCapture(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CaptureView()),
    );
    if (saved == true && context.mounted) {
      _afterSave(context, 'Transaction saved from receipt.');
    }
  }

  Future<void> _openManual(BuildContext context) async {
    context.read<TransactionViewModel>().startManualDraft();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ManualTransactionView()),
    );
    if (saved == true && context.mounted) {
      _afterSave(context, 'Transaction added.');
    }
  }

  void _afterSave(BuildContext context, String message) {
    final tx = context.read<TransactionViewModel>();
    final budgets = context.read<BudgetViewModel>();
    context
        .read<ForecastViewModel>()
        .refreshForecast(tx.transactions, budgets.budgets);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = context.watch<TransactionViewModel>();
    final budgets = context.watch<BudgetViewModel>();
    final forecast = context.watch<ForecastViewModel>();

    final spent = tx.spentThisMonth;
    final limit = budgets.totalLimit;
    final ratio = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final atRisk = forecast.atRisk;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'History & export',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryView()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCapture(context),
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('Scan receipt'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            forecast.refreshForecast(tx.transactions, budgets.budgets),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ------------------------------------------------ Spent this month
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spent this month',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Fmt.money(spent),
                      style: theme.textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of ${Fmt.moneyRound(limit)} budget',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 12,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ratio >= 1
                              ? AppTheme.danger
                              : ratio > 0.85
                                  ? AppTheme.warning
                                  : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --------------------------------------------------- At-risk alert
            if (atRisk.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                color: AppTheme.warning.withValues(alpha: 0.10),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_outlined,
                      color: AppTheme.warning),
                  title: Text(
                    '${atRisk.length} ${atRisk.length == 1 ? "category" : "categories"} at risk this month',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(atRisk.map((r) => r.category).join(', ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onSeeInsights,
                ),
              ),
            ],

            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  'Recent transactions',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryView()),
                  ),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (tx.recent.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No transactions yet.\nScan a receipt to get started.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < tx.recent.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 62),
                      TransactionTile(transaction: tx.recent[i]),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openManual(context),
              icon: const Icon(Icons.add),
              label: const Text('Add manually'),
            ),
          ],
        ),
      ),
    );
  }
}
