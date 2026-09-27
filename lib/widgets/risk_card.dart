import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/forecast_result.dart';

/// Risk status card for a single category (mockup 6).
///
/// Per section 5.4, each category is condensed into *a single status* instead of
/// a set of figures, to reduce the user's cognitive load.
class RiskCard extends StatelessWidget {
  const RiskCard({super.key, required this.result, this.onTap});

  final ForecastResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (Color accent, IconData icon) = switch (result.state) {
      RiskState.atRisk => (AppTheme.danger, Icons.error_outline),
      RiskState.watch => (AppTheme.warning, Icons.warning_amber_outlined),
      RiskState.onTrack => (AppTheme.ok, Icons.check_circle_outline),
    };

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.category,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'predicted ${Fmt.moneyRound(result.predictedSpend)} '
                      'of ${Fmt.moneyRound(result.budgetLimit)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                result.state.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
