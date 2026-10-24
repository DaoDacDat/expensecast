import 'dart:io';
import 'dart:math';

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
        .where((t) =>
            t.timestamp.year == now.year && t.timestamp.month == now.month)
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
      category: Categories.food,
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

  /// Number of days of demo history generated on startup, so the GRU model
  /// (which needs 60 days) can be run right away.
  static const seedDays = 60;

  static const _foodMerchants = [
    'New World',
    'Countdown Metro',
    'PAK nSAVE',
    'Coffee Club',
    'Bird on a Wire',
    'Uber Eats',
    'Subway',
    'Burger Fuel',
  ];
  static const _transportMerchants = [
    'Z Energy',
    'BP Connect',
    'AT HOP top-up',
    'Uber',
  ];
  static const _otherMerchants = [
    'Kmart',
    'Warehouse Stationery',
    'Chemist Warehouse',
    'Mercury Energy',
    'Chorus Broadband',
  ];

  /// Generates random spending for the last [seedDays] days (day 0 = today).
  /// A fixed seed keeps the demo data the same on every launch.
  void _seedMockData() {
    final rng = Random(42);
    final now = DateTime.now();
    var n = 0;

    double money(double min, double max) =>
        double.parse((min + rng.nextDouble() * (max - min)).toStringAsFixed(2));

    void add(int daysAgo, String merchant, double amount, String category) {
      var at = DateTime(now.year, now.month, now.day - daysAgo,
          8 + rng.nextInt(12), rng.nextInt(60));
      if (at.isAfter(now)) {
        at = now.subtract(Duration(minutes: rng.nextInt(60)));
      }
      final scanned = rng.nextBool();
      _transactions.add(
        Transaction(
          id: 'tx_seed_${n++}',
          merchant: merchant,
          amount: amount,
          category: category,
          timestamp: at,
          source: scanned ? TxSource.ocrCapture : TxSource.manualEntry,
          ocrConfidence: scanned ? 0.8 + rng.nextDouble() * 0.19 : 1.0,
        ),
      );
    }

    String pick(List<String> l) => l[rng.nextInt(l.length)];

    for (var d = 0; d < seedDays; d++) {
      final weekday = DateTime(now.year, now.month, now.day - d).weekday;
      final weekend = weekday >= DateTime.saturday;

      // Food: most days, bigger and more frequent at weekends.
      // Always present on the first and last day so the history spans 60 days.
      if (d == 0 ||
          d == seedDays - 1 ||
          rng.nextDouble() < (weekend ? 0.9 : 0.65)) {
        final big = rng.nextDouble() < 0.2;
        add(
            d,
            pick(_foodMerchants),
            big ? money(60, 130) : money(5, weekend ? 45 : 25),
            Categories.food);
      }
      if (weekend && rng.nextDouble() < 0.5) {
        add(d, pick(_foodMerchants), money(10, 40), Categories.food);
      }

      // Transport: roughly every second or third day.
      if (rng.nextDouble() < 0.35) {
        add(d, pick(_transportMerchants), money(10, 65), Categories.transport);
      }

      // Other: occasional purchases plus a monthly bill.
      if (rng.nextDouble() < 0.15) {
        add(d, pick(_otherMerchants), money(15, 90), Categories.other);
      }
      if (d % 30 == 5) {
        add(d, 'Mercury Energy', money(110, 160), Categories.other);
      }
    }
  }
}
