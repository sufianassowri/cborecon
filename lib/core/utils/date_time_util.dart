import 'package:intl/intl.dart';

class DateTimeUtil {
  DateTimeUtil._();

  static final DateFormat _displayFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _dateOnlyFormat = DateFormat('yyyy-MM-dd');
  static final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _displayFormat.format(dateTime);
  }

  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return _dateOnlyFormat.format(date);
  }

  static String formatCurrency(double? amount) {
    if (amount == null) return '0.00';
    return _currencyFormat.format(amount);
  }

  static bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
