import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/categories.dart';
import '../models/budget.dart';
import '../viewmodels/budget_view_model.dart';
import '../viewmodels/forecast_view_model.dart';
import '../viewmodels/transaction_view_model.dart';
import '../widgets/budget_progress_tile.dart';

/// Mockup 5: Budgets - đặt hạn mức theo danh mục và chu kỳ.
class BudgetView extends StatelessWidget {
  const BudgetView({super.key});

  Future<void> _editBudget(
    BuildContext context, {
    Budget? existing,
    String? newCategory,
  }) async {
    final vm = context.read<BudgetViewModel>();
    final category = existing?.category ?? newCategory!;
    final controller = TextEditingController(
      text: existing == null ? '' : existing.limit.toStringAsFixed(0),
    );

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Categories.iconFor(category),
                    color: Categories.colorFor(category)),
                const SizedBox(width: 10),
                Text(category, style: Theme.of(ctx).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: '${vm.period.label} limit',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(double.tryParse(controller.text) ?? 0),
              child: const Text('Save budget'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    controller.dispose();
    if (result == null || result <= 0) return;

    vm.updateBudget(
      Budget(category: category, limit: result, period: vm.period),
    );

    if (!context.mounted) return;
    final tx = context.read<TransactionViewModel>();
    context
        .read<ForecastViewModel>()
        .refreshForecast(tx.transactions, vm.budgets);
  }

  Future<void> _addCategoryBudget(BuildContext context) async {
    final vm = context.read<BudgetViewModel>();
    final available = vm.availableCategories;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Every category already has a budget.')),
      );
      return;
    }

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in available)
              ListTile(
                leading:
                    Icon(Categories.iconFor(c), color: Categories.colorFor(c)),
                title: Text(c),
                onTap: () => Navigator.of(ctx).pop(c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || !context.mounted) return;
    await _editBudget(context, newCategory: picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgets = context.watch<BudgetViewModel>();
    final tx = context.watch<TransactionViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Text(
                'Period',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<BudgetPeriod>(
                  showSelectedIcon: false,
                  segments: [
                    for (final p in BudgetPeriod.values)
                      ButtonSegment(
                        value: p,
                        label: Text(
                          p == BudgetPeriod.fortnightly ? '2-weekly' : p.label,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                  ],
                  selected: {budgets.period},
                  onSelectionChanged: (s) => budgets.setPeriod(s.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < budgets.budgets.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 12),
                  BudgetProgressTile(
                    category: budgets.budgets[i].category,
                    spent: tx.totalFor(budgets.budgets[i].category),
                    limit: budgets.budgets[i].limit,
                    onEdit: () =>
                        _editBudget(context, existing: budgets.budgets[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _addCategoryBudget(context),
            icon: const Icon(Icons.add),
            label: const Text('Add category budget'),
          ),
        ],
      ),
    );
  }
}
