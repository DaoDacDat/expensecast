import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/categories.dart';
import '../models/ocr_result.dart';
import '../models/transaction.dart';
import '../services/ocr_service.dart';

/// TransactionViewModel (Figure 8).
///
/// Holds the transaction list, the draft awaiting confirmation after OCR,
/// and the per-field edit operations on the Review screen.
class TransactionViewModel extends ChangeNotifier {
  TransactionViewModel({required OcrService ocrService})
      : _ocrService = ocrService {
    _seedMockData();
  }

  final OcrService _ocrService;

  final List<Transaction> _transactions = [];
  Transaction? _draft;
  OcrResult? _lastOcr;
  bool _isBusy = false;
  String? _error;

  /// List sorted newest first (a copy, cannot be modified from the View).
  List<Transaction> get transactions {
    final sorted = List<Transaction>.from(_transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(sorted);
  }
  Transaction? get draft => _draft;
  OcrResult? get lastOcr => _lastOcr;
  bool get isBusy => _isBusy;
  String? get error => _error;

  List<Transaction> get recent => transactions.take(5).toList();

  /// Total spending in the current month (the big number on the Home screen).
  double get spentThisMonth {
    final now = DateTime.now();
    return _transactions
        .where((t) => t.timestamp.year == now.year && t.timestamp.month == now.month)
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  double totalFor(String category) {
    final now = DateTime.now();
    return _transactions
        .where((t) =>
            t.category == category &&
            t.timestamp.year == now.year &&
            t.timestamp.month == now.month)
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  // ---------------------------------------------------------------- OCR flow

  /// Step 1.1 in the sequence diagram: addFromReceipt(image).
  ///
  /// Runs OCR and then creates a draft; the draft is NOT saved until the user
  /// taps "Save transaction" on the Review screen.
  Future<bool> addFromReceipt(File image) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _ocrService.extract(image);
      _lastOcr = result;
      _draft = Transaction(
        id: _newId(),
        merchant: result.merchant.value,
        amount: result.amount.value,
        category: result.category.value,
        timestamp: result.date.value,
        source: TxSource.ocrCapture,
        ocrConfidence: result.overallConfidence,
      );
      return true;
    } catch (e) {
      _error = 'Could not read this receipt. Try again or add it manually.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Starts an empty draft for the manual entry flow.
  void startManualDraft() {
    _lastOcr = null;
    _draft = Transaction(
      id: _newId(),
      merchant: '',
      amount: 0,
      category: Categories.groceries,
      timestamp: DateTime.now(),
      source: TxSource.manualEntry,
    );
    notifyListeners();
  }

  /// correctField(f, v) - the user edits a field on the Review screen.
  void correctField({
    String? merchant,
    double? amount,
    String? category,
    DateTime? timestamp,
  }) {
    final d = _draft;
    if (d == null) return;
    final wasOcr = d.source == TxSource.ocrCapture;
    _draft = d.copyWith(
      merchant: merchant,
      amount: amount,
      category: category,
      timestamp: timestamp,
      source: wasOcr ? TxSource.correctedOcr : d.source,
    );
    notifyListeners();
  }

  /// commitDraft() - step 3.1 in the sequence diagram.
  bool commitDraft() {
    final d = _draft;
    if (d == null) return false;
    if (d.merchant.trim().isEmpty || d.amount <= 0) {
      _error = 'Merchant and amount are required.';
      notifyListeners();
      return false;
    }
    _transactions.add(d);
    _draft = null;
    _lastOcr = null;
    _error = null;
    notifyListeners();
    return true;
  }

  void discardDraft() {
    _draft = null;
    _lastOcr = null;
    _error = null;
    notifyListeners();
  }

  // ------------------------------------------------------------ manual edits

  void addManual(Transaction tx) {
    _transactions.add(tx);
    notifyListeners();
  }

  void editTransaction(Transaction updated) {
    final i = _transactions.indexWhere((t) => t.id == updated.id);
    if (i == -1) return;
    _transactions[i] = updated;
    notifyListeners();
  }

  void remove(String id) {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// Export CSV (History & Export section). Returns a string for the screen to display
  /// or to write to a file at a later stage.
  String toCsv() {
    final buffer = StringBuffer('date,merchant,category,amount,source\n');
    for (final t in transactions) {
      final merchant = t.merchant.replaceAll(',', ' ');
      buffer.writeln(
        '${t.timestamp.toIso8601String()},$merchant,${t.category},'
        '${t.amount.toStringAsFixed(2)},${t.source.name}',
      );
    }
    return buffer.toString();
  }

  String _newId() =>
      'tx_${DateTime.now().microsecondsSinceEpoch}_${_transactions.length}';

  // -------------------------------------------------------------- mock data

  void _seedMockData() {
    final now = DateTime.now();
    _transactions.addAll([
      Transaction(
        id: 'tx_seed_1',
        merchant: 'New World',
        amount: 54.20,
        category: Categories.groceries,
        timestamp: now.subtract(const Duration(hours: 4)),
        source: TxSource.ocrCapture,
        ocrConfidence: 0.94,
      ),
      Transaction(
        id: 'tx_seed_2',
        merchant: 'Z Energy',
        amount: 61.00,
        category: Categories.transport,
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        source: TxSource.ocrCapture,
        ocrConfidence: 0.91,
      ),
      Transaction(
        id: 'tx_seed_3',
        merchant: 'Coffee Club',
        amount: 5.50,
        category: Categories.eatingOut,
        timestamp: now.subtract(const Duration(days: 2)),
        source: TxSource.manualEntry,
      ),
      Transaction(
        id: 'tx_seed_4',
        merchant: 'Countdown Metro',
        amount: 118.35,
        category: Categories.groceries,
        timestamp: now.subtract(const Duration(days: 4)),
        source: TxSource.ocrCapture,
        ocrConfidence: 0.88,
      ),
      Transaction(
        id: 'tx_seed_5',
        merchant: 'Mercury Energy',
        amount: 142.10,
        category: Categories.utilities,
        timestamp: now.subtract(const Duration(days: 6)),
        source: TxSource.correctedOcr,
        ocrConfidence: 0.71,
      ),
      Transaction(
        id: 'tx_seed_6',
        merchant: 'AT HOP top-up',
        amount: 40.00,
        category: Categories.transport,
        timestamp: now.subtract(const Duration(days: 8)),
        source: TxSource.manualEntry,
      ),
      Transaction(
        id: 'tx_seed_7',
        merchant: 'Bird on a Wire',
        amount: 28.50,
        category: Categories.eatingOut,
        timestamp: now.subtract(const Duration(days: 9)),
        source: TxSource.ocrCapture,
        ocrConfidence: 0.96,
      ),
      Transaction(
        id: 'tx_seed_8',
        merchant: 'PAK nSAVE',
        amount: 96.80,
        category: Categories.groceries,
        timestamp: now.subtract(const Duration(days: 12)),
        source: TxSource.ocrCapture,
        ocrConfidence: 0.93,
      ),
      Transaction(
        id: 'tx_seed_9',
        merchant: 'Uber Eats',
        amount: 34.90,
        category: Categories.eatingOut,
        timestamp: now.subtract(const Duration(days: 14)),
        source: TxSource.manualEntry,
      ),
      Transaction(
        id: 'tx_seed_10',
        merchant: 'Chorus Broadband',
        amount: 79.99,
        category: Categories.utilities,
        timestamp: now.subtract(const Duration(days: 18)),
        source: TxSource.ocrCapture,
        ocrConfidence: 0.90,
      ),
      Transaction(
        id: 'tx_seed_11',
        merchant: 'Kmart',
        amount: 24.00,
        category: Categories.other,
        timestamp: now.subtract(const Duration(days: 21)),
        source: TxSource.manualEntry,
      ),
      Transaction(
        id: 'tx_seed_12',
        merchant: 'BP Connect',
        amount: 55.00,
        category: Categories.transport,
        timestamp: now.subtract(const Duration(days: 24)),
        source: TxSource.ocrCapture,
        ocrConfidence: 0.89,
      ),
    ]);
  }
}
