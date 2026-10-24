import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/categories.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../viewmodels/transaction_view_model.dart';
import '../widgets/category_picker.dart';
import '../widgets/privacy_note.dart';
import 'manual_transaction_view.dart';

/// Mockup 4: OCR Review & Confirm - "Check the details".
///
/// Every OCR field is an editable input, and the warning names exactly the field
/// the recogniser is least confident about (section 5.4), so a fix takes only one tap.
class ReviewView extends StatefulWidget {
  const ReviewView({super.key, this.imageFile});

  final File? imageFile;

  @override
  State<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<ReviewView> {
  late final TextEditingController _merchant;
  late final TextEditingController _amount;
  late DateTime _date;
  late String _category;

  @override
  void initState() {
    super.initState();
    final draft = context.read<TransactionViewModel>().draft;
    _merchant = TextEditingController(text: draft?.merchant ?? '');
    _amount = TextEditingController(
      text: draft == null ? '' : draft.amount.toStringAsFixed(2),
    );
    _date = draft?.timestamp ?? DateTime.now();
    _category = draft?.category ?? Categories.food;
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
    final vm = context.read<TransactionViewModel>();
    vm.correctField(
      merchant: _merchant.text.trim(),
      amount: double.tryParse(_amount.text.replaceAll(',', '')) ?? 0,
      category: _category,
      timestamp: _date,
    );
    final ok = vm.commitDraft();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'Please check the fields.')),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _discard() {
    context.read<TransactionViewModel>().discardDraft();
    Navigator.of(context).pop(false);
  }

  Future<void> _editManually() async {
    // Go straight to the manual entry screen, keeping the current draft
    // (the "edit fields / low OCR confidence" edge in Figure 9).
    context.read<TransactionViewModel>().correctField(
          merchant: _merchant.text.trim(),
          amount: double.tryParse(_amount.text.replaceAll(',', '')) ?? 0,
          category: _category,
          timestamp: _date,
        );
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ManualTransactionView()),
    );
    if (!mounted) return;
    if (saved == true) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<TransactionViewModel>();
    final ocr = vm.lastOcr;
    final weakField = ocr?.weakestFieldName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check the details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _discard,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                widget.imageFile!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (widget.imageFile != null) const SizedBox(height: 18),
          _FieldLabel('Merchant', confidence: ocr?.merchant.confidence),
          TextField(
            controller: _merchant,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Shop name'),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Amount', confidence: ocr?.amount.confidence),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              prefixText: '\$ ',
              hintText: '0.00',
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Date', confidence: ocr?.date.confidence),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
              ),
              child: Text(Fmt.date(_date)),
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Category (suggested)',
              confidence: ocr?.category.confidence),
          CategoryPicker(
            value: _category,
            highlighted: ocr != null,
            onChanged: (v) => setState(() => _category = v),
          ),
          if (weakField != null) ...[
            const SizedBox(height: 18),
            PrivacyNote(
              icon: Icons.help_outline,
              dense: true,
              text: 'Low confidence on $weakField — please check it '
                  'before saving.',
            ),
          ],
          const SizedBox(height: 26),
          FilledButton(
            onPressed: _save,
            child: const Text('Save transaction'),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _editManually,
                child: const Text('Edit manually'),
              ),
              Text('·',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              TextButton(
                onPressed: _discard,
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Field label with a coloured dot showing that field's own OCR confidence.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.confidence});

  final String text;
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = confidence;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (c != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c >= 0.9
                    ? AppTheme.ok
                    : c >= 0.75
                        ? AppTheme.warning
                        : AppTheme.danger,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(c * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
