import 'dart:math';
import 'dart:ui' show Rect;

import '../core/categories.dart';
import '../models/ocr_result.dart';

/// Một dòng chữ do bộ nhận dạng trả về, kèm vị trí trên ảnh.
///
/// Tách khỏi kiểu `TextLine` của ML Kit để [ReceiptParser] là Dart thuần,
/// test được mà không cần native plugin.
class ReceiptLine {
  final String text;
  final Rect box;

  /// Độ tin cậy của bộ nhận dạng cho dòng này (ML Kit có thể trả null).
  final double? confidence;

  const ReceiptLine(this.text, this.box, {this.confidence});
}

/// Các dòng nằm cùng một hàng ngang trên hoá đơn, đã nối từ trái sang phải.
///
/// ML Kit hay tách "TOTAL" và "$54.20" thành hai block riêng vì chúng ở hai
/// cột, nên phải ghép lại theo toạ độ thì mới đọc được cặp nhãn - giá trị.
class _Row {
  _Row(ReceiptLine first) : lines = [first];

  final List<ReceiptLine> lines;

  double get top => lines.map((l) => l.box.top).reduce(min);
  double get bottom => lines.map((l) => l.box.bottom).reduce(max);
  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;

  String get text => (List<ReceiptLine>.from(lines)
        ..sort((a, b) => a.box.left.compareTo(b.box.left)))
      .map((l) => l.text)
      .join(' ');

  String get lower => text.toLowerCase();

  double get confidence {
    final known = lines.map((l) => l.confidence).whereType<double>();
    // iOS không trả confidence từng dòng; coi như nhận dạng tốt.
    if (known.isEmpty) return _defaultLineConfidence;
    return known.reduce(min);
  }
}

const _defaultLineConfidence = 0.95;

/// Chuyển văn bản OCR thô thành các trường của giao dịch bằng heuristic.
///
/// Mỗi trường mang confidence = (độ chắc của heuristic) x (confidence OCR của
/// dòng chứa nó), để màn hình Review chỉ đúng trường cần người dùng kiểm tra.
class ReceiptParser {
  ReceiptParser({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  OcrResult parse(List<ReceiptLine> lines, {required String imagePath}) {
    final rows = _groupRows(lines);
    final merchant = _merchant(rows);
    return OcrResult(
      merchant: merchant,
      amount: _amount(rows),
      date: _date(rows),
      category: _category(merchant.value, rows),
      imagePath: imagePath,
    );
  }

  // ------------------------------------------------------------------- rows

  List<_Row> _groupRows(List<ReceiptLine> lines) {
    final sorted = lines.where((l) => l.text.trim().isNotEmpty).toList()
      ..sort((a, b) => a.box.center.dy.compareTo(b.box.center.dy));

    final rows = <_Row>[];
    for (final line in sorted) {
      final last = rows.isEmpty ? null : rows.last;
      final tolerance =
          last == null ? 0.0 : min(line.box.height, last.height) * 0.5;
      if (last != null &&
          (line.box.center.dy - last.centerY).abs() <= tolerance) {
        last.lines.add(line);
      } else {
        rows.add(_Row(line));
      }
    }
    return rows;
  }

  // --------------------------------------------------------------- merchant

  static final _merchantSkip = RegExp(
    r'tax invoice|invoice|receipt|welcome|thank|gst|abn|phone|\btel\b|'
    r'\bph\b|www\.|http|@|\bdate\b|\btime\b|order|table|customer copy|'
    r'merchant copy|eftpos|terminal',
  );

  OcrField<String> _merchant(List<_Row> rows) {
    // Tên cửa hàng gần như luôn nằm trong vài hàng đầu tiên.
    for (final (i, row) in rows.take(6).indexed) {
      final text = row.text.trim();
      final letters = RegExp(r'[A-Za-z]').allMatches(text).length;
      if (letters < 3 || letters / text.length < 0.5) continue;
      if (_merchantSkip.hasMatch(row.lower)) continue;

      final score = i == 0 ? 0.9 : 0.8;
      return OcrField(_tidyName(text), score * row.confidence);
    }
    return const OcrField('', 0);
  }

  /// "NEW WORLD VICTORIA ST" -> "New World Victoria St".
  String _tidyName(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed != collapsed.toUpperCase()) return collapsed;
    return collapsed
        .split(' ')
        .map((w) => w.length <= 1
            ? w
            : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  // ----------------------------------------------------------------- amount

  /// Số tiền có đúng hai chữ số thập phân: 54.20, $1,234.50, 54,20.
  /// Không bắt đầu/kết thúc giữa một dãy số khác (vd. ngày 18.08.26).
  static final _money = RegExp(
    r'(?<![\d.,])(\d{1,3}(?:,\d{3})+|\d+)[.,](\d{2})(?![.,]?\d)',
  );

  /// Nhãn tổng tiền, xếp theo độ ưu tiên giảm dần.
  static const _totalKeywords = <String>[
    'grand total',
    'total due',
    'amount due',
    'balance due',
    'total',
    'amount',
    'eftpos',
    'visa',
    'mastercard',
    'card',
  ];

  /// Hàng có số tiền nhưng không phải tổng phải trả. "TOTAL INCL GST 54.20"
  /// vẫn là tổng, còn "GST 7.07" hay "Total includes GST 7.07" thì không.
  static final _notTotal = RegExp(
    r'sub\s*-?\s*total|(?<!incl\.?\s*|including\s*)gst|\btax\b|discount|'
    r'saving|saved|change|rounding|cash|tendered|\bqty\b|items?\b|points',
  );

  OcrField<double> _amount(List<_Row> rows) {
    OcrField<double>? best;
    var bestRank = _totalKeywords.length;

    for (final (i, row) in rows.indexed) {
      final lower = row.lower;
      if (_notTotal.hasMatch(lower)) continue;
      final rank = _totalKeywords.indexWhere(lower.contains);
      if (rank < 0 || rank > bestRank) continue;

      // Số tiền cùng hàng, hoặc ở hàng ngay dưới nếu hàng đó chỉ có số.
      var value = _lastMoney(row.text);
      var conf = row.confidence;
      if (value == null && i + 1 < rows.length) {
        final next = rows[i + 1];
        if (!RegExp(r'[A-Za-z]{2,}').hasMatch(next.text)) {
          value = _lastMoney(next.text);
          conf = next.confidence;
        }
      }
      if (value == null || value <= 0) continue;

      final score = rank <= 4 ? 0.95 : 0.8;
      final candidate = OcrField(value, score * conf);
      // Cùng độ ưu tiên thì lấy số lớn hơn (TOTAL thường >= các dòng khác).
      if (rank < bestRank || best == null || value > best.value) {
        best = candidate;
        bestRank = rank;
      }
    }
    if (best != null) return best;

    // Không thấy nhãn tổng: lấy số tiền lớn nhất, nhưng kém tự tin.
    OcrField<double>? largest;
    for (final row in rows) {
      if (_notTotal.hasMatch(row.lower)) continue;
      for (final m in _money.allMatches(row.text)) {
        final value = _toDouble(m);
        if (largest == null || value > largest.value) {
          largest = OcrField(value, 0.6 * row.confidence);
        }
      }
    }
    return largest ?? const OcrField(0.0, 0);
  }

  double? _lastMoney(String text) {
    final matches = _money.allMatches(text);
    return matches.isEmpty ? null : _toDouble(matches.last);
  }

  double _toDouble(RegExpMatch m) =>
      double.parse('${m.group(1)!.replaceAll(',', '')}.${m.group(2)}');

  // ------------------------------------------------------------------- date

  static const _months = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static final _isoDate = RegExp(r'\b(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})\b');
  static final _numericDate =
      RegExp(r'\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})\b');
  static final _dayMonthName = RegExp(
    r'\b(\d{1,2})(?:st|nd|rd|th)?[\s-]*(jan|feb|mar|apr|may|jun|jul|aug|sep|'
    r'oct|nov|dec)[a-z]*\.?[\s,-]*(\d{4}|\d{2})\b',
  );
  static final _monthNameDay = RegExp(
    r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+'
    r'(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b',
  );

  OcrField<DateTime> _date(List<_Row> rows) {
    OcrField<DateTime>? best;
    for (final row in rows) {
      final found = _findDate(row.lower);
      if (found == null) continue;
      final (date, score) = found;
      // Hàng có chữ "date" đáng tin hơn các ngày khác (vd. hạn đổi trả).
      final boost = row.lower.contains('date') ? 1.0 : 0.95;
      final candidate = OcrField(date, score * boost * row.confidence);
      if (best == null || candidate.confidence > best.confidence) {
        best = candidate;
      }
    }
    return best ?? OcrField(_clock(), 0.3);
  }

  (DateTime, double)? _findDate(String text) {
    for (final m in _isoDate.allMatches(text)) {
      final d = _validDate(_int(m, 1), _int(m, 2), _int(m, 3));
      if (d != null) return (d, 0.95);
    }
    for (final m in _dayMonthName.allMatches(text)) {
      final d = _validDate(_year(m, 3), _months[m.group(2)]!, _int(m, 1));
      if (d != null) return (d, 0.95);
    }
    for (final m in _monthNameDay.allMatches(text)) {
      final d = _validDate(_year(m, 3), _months[m.group(1)]!, _int(m, 2));
      if (d != null) return (d, 0.95);
    }
    for (final m in _numericDate.allMatches(text)) {
      final a = _int(m, 1), b = _int(m, 2), y = _year(m, 3);
      // Mặc định ngày trước tháng (định dạng NZ); chỉ đọc kiểu Mỹ khi số
      // thứ hai không thể là tháng (vd. 09/13/2026).
      if (b <= 12) {
        final d = _validDate(y, b, a);
        if (d != null) return (d, a <= 12 && a != b ? 0.8 : 0.9);
      } else {
        final d = _validDate(y, a, b);
        if (d != null) return (d, 0.85);
      }
    }
    return null;
  }

  int _int(RegExpMatch m, int group) => int.parse(m.group(group)!);

  int _year(RegExpMatch m, int group) {
    final y = _int(m, group);
    return y < 100 ? 2000 + y : y;
  }

  /// Chỉ nhận ngày có thật, không ở tương lai và không quá 5 năm trước
  /// (cũng giữ ngày trong khoảng mà date picker ở màn Review cho phép).
  DateTime? _validDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final d = DateTime(year, month, day);
    if (d.month != month || d.day != day) return null;
    final now = _clock();
    if (d.isAfter(now)) return null;
    if (d.isBefore(DateTime(now.year - 5, now.month, now.day))) return null;
    return d;
  }

  // --------------------------------------------------------------- category

  static final _categoryKeywords = <String, List<String>>{
    Categories.groceries: [
      'new world',
      'countdown',
      'woolworths',
      "pak'n",
      'paknsave',
      'pak n save',
      'four square',
      'freshchoice',
      'fresh choice',
      'supervalue',
      'supermarket',
      'grocer',
      'butcher',
      'produce',
    ],
    Categories.transport: [
      'z energy',
      r'\bbp\b',
      'mobil',
      'caltex',
      'gull',
      'waitomo',
      'fuel',
      'petrol',
      'diesel',
      'unleaded',
      'parking',
      'at hop',
      'uber',
      'taxi',
      r'\bbus\b',
      'train',
    ],
    Categories.eatingOut: [
      'cafe',
      'café',
      'coffee',
      'restaurant',
      r'\bbar\b',
      'kitchen',
      'eatery',
      'pizza',
      'burger',
      'sushi',
      'mcdonald',
      'kfc',
      'subway',
      'domino',
      'starbucks',
      r'\btable\b',
      'takeaway',
      'latte',
      'flat white',
      'bakery',
    ],
    Categories.utilities: [
      'mercury',
      'genesis',
      'contact energy',
      'meridian',
      'electricity',
      'power',
      r'\bwater\b',
      'spark',
      'one nz',
      'vodafone',
      '2degrees',
      'broadband',
      'internet',
    ],
  };

  OcrField<String> _category(String merchant, List<_Row> rows) {
    final name = merchant.toLowerCase();
    final body = rows.map((r) => r.lower).join('\n');

    var bestCategory = Categories.other;
    var bestScore = 0;
    var fromMerchant = false;

    for (final entry in _categoryKeywords.entries) {
      var score = 0;
      var merchantHit = false;
      for (final keyword in entry.value) {
        final re = RegExp(keyword);
        if (re.hasMatch(name)) {
          score += 3;
          merchantHit = true;
        } else if (re.hasMatch(body)) {
          score += 1;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestCategory = entry.key;
        fromMerchant = merchantHit;
      }
    }

    if (bestScore == 0) return const OcrField(Categories.other, 0.4);
    if (fromMerchant) return OcrField(bestCategory, 0.9);
    return OcrField(bestCategory, bestScore >= 2 ? 0.8 : 0.65);
  }
}
