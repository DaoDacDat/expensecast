import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/categories.dart';
import '../core/formatters.dart';
import '../models/transaction.dart';
import '../viewmodels/transaction_view_model.dart';
import '../widgets/category_picker.dart';

/// Manual Transaction screen (Figure 9).
///
/// Used for both flows: adding manually from Home, and continuing to edit when OCR
/// returns low-confidence results from the Review screen.
class ManualTransactionView extends StatefulWidget {
  const ManualTransactionView({super.key, this.existing});

  /// When non-null, the screen is in edit mode for a saved transaction.
  final Transaction? existing;

  @override
  State<ManualTransactionView> createState() => _ManualTransactionViewState();
}

class _ManualTransactionViewState extends State<ManualTransactionView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchant;
  late final TextEditingController _amount;
  late DateTime _date;
  late String _category;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final source =
        widget.existing ?? context.read<TransactionViewModel>().draft;
    _merchant = TextEditingController(text: source?.merchant ?? '');
    _amount = TextEditingController(
      text: (source == null || source.amount == 0)
          ? ''
          : source.amount.toStringAsFixed(2),
    );
    _date = source?.timestamp ?? DateTime.now();
    _category = source?.category ?? Categories.groceries;
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vm = context.read<TransactionViewModel>();
    final amount = double.parse(_amount.text.replaceAll(',', ''));

    if (_isEditing) {
      vm.editTransaction(
        widget.existing!.copyWith(
          merchant: _merchant.text.trim(),
          amount: amount,
          category: _category,
          timestamp: _date,
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }

    vm.correctField(
      merchant: _merchant.text.trim(),
      amount: amount,
      category: _category,
      timestamp: _date,
    );
    if (vm.commitDraft()) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'Please check the fields.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit transaction' : 'Add transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            TextFormField(
              controller: _merchant,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Merchant',
                hintText: 'e.g. New World Victoria St',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the merchant name'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
                hintText: '0.00',
              ),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').replaceAll(',', ''));
                if (parsed == null) return 'Enter a number';
                if (parsed <= 0) return 'Amount must be greater than zero';
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(Fmt.date(_date)),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  'Category',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
            CategoryPicker(
              value: _category,
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Save transaction'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                if (!_isEditing) {
                  context.read<TransactionViewModel>().discardDraft();
                }
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
