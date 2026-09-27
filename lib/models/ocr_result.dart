/// Một trường được OCR trích xuất, kèm độ tin cậy riêng của trường đó.
///
/// Mockup số 4 trong báo cáo nêu rõ: màn hình Review phải chỉ ra *trường nào*
/// máy nhận dạng kém tự tin nhất, chứ không chỉ một điểm confidence tổng.
class OcrField<T> {
  final T value;
  final double confidence;

  const OcrField(this.value, this.confidence);

  bool get isLowConfidence => confidence < 0.75;
}

/// Kết quả OCR trả về từ MlKitOcrService.extract().
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

  /// Trường có độ tin cậy thấp nhất - dùng để hiện cảnh báo
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
