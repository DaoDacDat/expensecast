import 'package:flutter/material.dart';

import '../core/categories.dart';
import '../core/formatters.dart';
import '../core/theme.dart';

/// Per-category budget progress bar (mockup 5 - Budgets).
class BudgetProgressTile extends StatelessWidget {
  const BudgetProgressTile({
    super.key,
    required this.category,
    required this.spent,
    required this.limit,
    this.onEdit,
  });

  final String category;
  final double spent;
  final double limit;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final over = limit > 0 && spent > limit;

    final barColor = over
        ? AppTheme.danger
        : ratio > 0.85
            ? AppTheme.warning
            : Categories.colorFor(category);

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Categories.iconFor(category),
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  Fmt.moneyRound(limit),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              over
                  ? '${Fmt.money(spent)} spent · over by ${Fmt.money(spent - limit)}'
                  : '${Fmt.money(spent)} spent · ${Fmt.money(limit - spent)} left',
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    over ? AppTheme.danger : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
