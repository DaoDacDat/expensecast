import 'dart:io';

import 'package:expensecast/core/categories.dart';
import 'package:expensecast/models/budget.dart';
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
        category: const OcrField(Categories.groceries, 0.88),
        imagePath: image.path,
      );
}

class _FixedForecastService implements ForecastService {
  @override
  Future<List<ForecastResult>> predict(
    List<Transaction> transactions,
    List<Budget> budgets,
  ) async =>
      const [
        ForecastResult(
          category: Categories.eatingOut,
          predictedSpend: 168,
          budgetLimit: 150,
          riskRatio: 1.12,
        ),
      ];
}

void main() {
  group('TransactionViewModel', () {
    test('OCR tạo bản nháp nhưng chưa lưu cho tới khi commit', () async {
      final vm = TransactionViewModel(ocrService: _FixedOcrService());
      final before = vm.transactions.length;

      await vm.addFromReceipt(File('fake_receipt.jpg'));

      expect(vm.draft, isNotNull);
      expect(vm.draft!.merchant, 'Test Mart');
      expect(vm.transactions.length, before, reason: 'chưa commit');

      expect(vm.commitDraft(), isTrue);
      expect(vm.transactions.length, before + 1);
      expect(vm.draft, isNull);
    });

    test('sửa trường của bản nháp OCR đổi nguồn thành correctedOcr', () async {
      final vm = TransactionViewModel(ocrService: _FixedOcrService());
      await vm.addFromReceipt(File('fake_receipt.jpg'));

      vm.correctField(amount: 99.99);

      expect(vm.draft!.amount, 99.99);
      expect(vm.draft!.source, TxSource.correctedOcr);
    });

    test('không lưu được khi thiếu merchant hoặc số tiền', () {
      final vm = TransactionViewModel(ocrService: _FixedOcrService());
      vm.startManualDraft();

      expect(vm.commitDraft(), isFalse);
      expect(vm.error, isNotNull);
    });

    test('trường yếu nhất được nêu đích danh', () async {
      final vm = TransactionViewModel(ocrService: _FixedOcrService());
      await vm.addFromReceipt(File('fake_receipt.jpg'));

      expect(vm.lastOcr!.weakestFieldName, 'Amount');
    });
  });

  group('ForecastViewModel', () {
    test('lọc ra danh mục vượt hạn mức', () async {
      final vm = ForecastViewModel(service: _FixedForecastService());
      await vm.refreshForecast(const [], const []);

      expect(vm.results.length, 1);
      expect(vm.atRisk.length, 1);
      expect(vm.results.first.state, RiskState.atRisk);
    });
  });
}
