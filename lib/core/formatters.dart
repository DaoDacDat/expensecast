import 'package:intl/intl.dart';

/// Shared currency and date formatting (defaults to NZD as in the mockup).
class Fmt {
  static final _money = NumberFormat.currency(
    locale: 'en_NZ',
    symbol: '\$',
    decimalDigits: 2,
  );
  static final _moneyCompact = NumberFormat.currency(
    locale: 'en_NZ',
    symbol: '\$',
    decimalDigits: 0,
  );
  static final _date = DateFormat('d MMM yyyy');
  static final _dateShort = DateFormat('d MMM');

  static String money(double v) => _money.format(v);
  static String moneyRound(double v) => _moneyCompact.format(v);
  static String date(DateTime d) => _date.format(d);
  static String dateShort(DateTime d) => _dateShort.format(d);

  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return dateShort(d);
  }
}
