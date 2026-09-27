import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/categories.dart';
import '../core/formatters.dart';
import '../models/transaction.dart';
import '../viewmodels/transaction_view_model.dart';
import '../widgets/transaction_tile.dart';
import 'manual_transaction_view.dart';

/// History & Export (mục 1.2.1: xem lịch sử và xuất CSV).
class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  String? _filter;

  Future<void> _exportCsv() async {
    final csv = context.read<TransactionViewModel>().toCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV copied to clipboard (file export comes in Sprint 3).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<TransactionViewModel>();

    final items = _filter == null
        ? vm.transactions
        : vm.transactions.where((t) => t.category == _filter).toList();

    final total = items.fold<double>(0, (s, t) => s + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History & Export'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.ios_share),
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 10),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final c in Categories.all)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 10),
                    child: FilterChip(
                      label: Text(c),
                      selected: _filter == c,
                      onSelected: (_) => setState(() => _filter = c),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Text(
                  '${items.length} transactions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  Fmt.money(total),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Nothing here yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 62),
                    itemBuilder: (context, i) => Dismissible(
                      key: ValueKey(items[i].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: theme.colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(Icons.delete_outline,
                            color: theme.colorScheme.onErrorContainer),
                      ),
                      onDismissed: (_) => _delete(items[i]),
                      child: TransactionTile(
                        transaction: items[i],
                        showDate: true,
                        onTap: () => _edit(items[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _delete(Transaction t) {
    final vm = context.read<TransactionViewModel>();
    vm.remove(t.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${t.merchant} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => vm.addManual(t),
        ),
      ),
    );
  }

  Future<void> _edit(Transaction t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ManualTransactionView(existing: t)),
    );
  }
}
