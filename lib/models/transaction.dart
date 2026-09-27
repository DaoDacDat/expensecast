/// Nguồn gốc của một giao dịch - tương ứng enum TxSource trong class diagram.
enum TxSource {
  ocrCapture,
  manualEntry,
  correctedOcr;

  String get label => switch (this) {
        TxSource.ocrCapture => 'scanned',
        TxSource.manualEntry => 'manual',
        TxSource.correctedOcr => 'corrected',
      };
}

/// Entity Transaction (Figure 8 - MVVM Class Diagram).
class Transaction {
  final String id;
  final String merchant;
  final double amount;
  final String category;
  final DateTime timestamp;
  final TxSource source;

  /// Độ tin cậy OCR 0..1 (chỉ có ý nghĩa khi source != manualEntry).
  final double ocrConfidence;

  const Transaction({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.timestamp,
    required this.source,
    this.ocrConfidence = 1.0,
  });

  Transaction copyWith({
    String? id,
    String? merchant,
    double? amount,
    String? category,
    DateTime? timestamp,
    TxSource? source,
    double? ocrConfidence,
  }) {
    return Transaction(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'merchant': merchant,
        'amount': amount,
        'category': category,
        'timestamp': timestamp.toIso8601String(),
        'source': source.name,
        'ocrConfidence': ocrConfidence,
      };

  factory Transaction.fromMap(Map<String, Object?> m) => Transaction(
        id: m['id'] as String,
        merchant: m['merchant'] as String,
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String,
        timestamp: DateTime.parse(m['timestamp'] as String),
        source: TxSource.values.firstWhere(
          (e) => e.name == m['source'],
          orElse: () => TxSource.manualEntry,
        ),
        ocrConfidence: (m['ocrConfidence'] as num?)?.toDouble() ?? 1.0,
      );
}
