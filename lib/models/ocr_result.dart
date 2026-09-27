/// A field extracted by OCR, with its own per-field confidence.
///
/// Mockup 4 in the report states that the Review screen must point out *which field*
/// the recogniser is least confident about, not just an overall confidence score.
class OcrField<T> {
  final T value;
  final double confidence;

  const OcrField(this.value, this.confidence);

  bool get isLowConfidence => confidence < 0.75;
}

/// OCR result returned by MlKitOcrService.extract().
class OcrResult {
  final OcrField<String> merchant;
  final OcrField<double> amount;
  final OcrField<DateTime> date;
  final OcrField<String> category;
  final String imagePath;

  const OcrResult({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    required this.imagePath,
  });

  /// The field with the lowest confidence - used to show a warning
  /// "Low confidence on <field> — please check".
  String? get weakestFieldName {
    final entries = <String, double>{
      'Merchant': merchant.confidence,
      'Amount': amount.confidence,
      'Date': date.confidence,
      'Category': category.confidence,
    };
    var weakestKey = entries.keys.first;
    var weakest = entries[weakestKey]!;
    for (final e in entries.entries) {
      if (e.value < weakest) {
        weakest = e.value;
        weakestKey = e.key;
      }
    }
    return weakest < 0.75 ? weakestKey : null;
  }

  double get overallConfidence {
    final all = [
      merchant.confidence,
      amount.confidence,
      date.confidence,
      category.confidence,
    ];
    return all.reduce((a, b) => a + b) / all.length;
  }
}
