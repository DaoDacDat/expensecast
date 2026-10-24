import 'dart:io';

import 'package:expensecast/core/categories.dart';
import 'package:expensecast/models/budget.dart';
import 'package:expensecast/models/forecast_method.dart';
import 'package:expensecast/models/forecast_result.dart';
import 'package:expensecast/models/ocr_result.dart';
import 'package:expensecast/models/transaction.dart';
import 'package:expensecast/services/forecast_service.dart';
import 'package:expensecast/services/ocr_service.dart';
import 'package:expensecast/viewmodels/forecast_view_model.dart';
import 'package:expensecast/viewmodels/transaction_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// OCR stub with a fixed result - illustrates the testability point from section 7.3:
/// the ViewModel depends on an interface, so the real implementation can be swapped in tests.
class _FixedOcrService implements OcrService {
  @override
  Future<OcrResult> extract(File image) async => OcrResult(
        merchant: const OcrField('Test Mart', 0.95),
        amount: const OcrField(12.34, 0.60),
        date: OcrField(DateTime(2026, 8, 18), 0.92),
        category: const OcrField(Categories.food, 0.88),
        imagePath: image.path,
      );
}

class _FixedForecastService implements ForecastService {
  @override
  Future<List<ForecastResult>> predict(
    List<Transaction> transactions,
    List<Budget> budgets, {
    ForecastMethod method = ForecastMethod.gru,
    ForecastHorizon horizon = ForecastHorizon.month,
  }) async =>
      const [
        ForecastResult(
          category: Categories.food,
          predictedSpend: 168,
          budgetLimit: 150,
          riskRatio: 1.12,
        ),
        ForecastResult(
          category: Categories.transport,
          predictedSpend: 90,
          budgetLimit: 200,
          riskRatio: 0.45,
        ),
      ];
}

void main() {
  group('TransactionViewModel', () {
    test('OCR creates a draft but does not save it until commit', () async {
      final vm = TransactionViewModel(ocrService: _FixedOcrService());
      final before = vm.transactions.length;

      await vm.addFromReceipt(File('fake_receipt.jpg'));

      expect(vm.draft, isNotNull);
      expect(vm.draft!.merchant, 'Test Mart');
      expect(vm.transactions.length, before, reason: 'not committed yet');

      expect(vm.commitDraft(), isTrue);
      expect(vm.transactions.length, before + 1);
      expect(vm.draft, isNull);
    });

    test('editing a field of an OCR draft changes its source to correctedOcr', () async {
      final vm = TransactionViewModel(ocrService: _FixedOcrService());
      await vm.addFromReceipt(File('fake_receipt.jpg'));

      vm.correctField(amount: 99.99);

      expect(vm.draft!.amount, 99.99);
      expect(vm.draft!.source, TxSource.correctedOcr);
    });

    test('cannot save when the merchant or amount is missing', () {
      final vm = TransactionViewModel(ocrService: _FixedOcrService());
      vm.startManualDraft();

      expect(vm.commitDraft(), isFalse);
      expect(vm.error, isNotNull);
    });

    test('the weakest field is named explicitly', () async {
      final vm = TransactionViewModel(ocrService: _FixedOcrService());
      await vm.addFromReceipt(File('fake_receipt.jpg'));

      expect(vm.lastOcr!.weakestFieldName, 'Amount');
    });
  });

  group('ForecastViewModel', () {
    test('filters out categories over their limit', () async {
      final vm = ForecastViewModel(service: _FixedForecastService());
      await vm.refreshForecast(const [], const []);

      expect(vm.results.length, 2);
      expect(vm.atRisk.length, 1);
      expect(vm.results.first.state, RiskState.atRisk);
    });

    test('selecting a category changes the charted result', () async {
      final vm = ForecastViewModel(service: _FixedForecastService());
      await vm.refreshForecast(const [], const []);
      expect(vm.selected!.category, Categories.food,
          reason: 'default: riskiest');

      vm.selectCategory(Categories.transport);
      expect(vm.selected!.category, Categories.transport);

      vm.selectCategory('Nope');
      expect(vm.selected!.category, Categories.food,
          reason: 'unknown category falls back to the first result');
    });
  });
}
