import 'package:intl/intl.dart';

/// Reusable utility for formatting dates, times, and date ranges.
class DateFormatter {
  DateFormatter._();

  static final DateFormat _dayMonthYear = DateFormat('dd MMM yyyy');
  static final DateFormat _shortDate = DateFormat('dd MMM');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _time12h = DateFormat('hh:mm a');

  static String formatFull(DateTime date) => _dayMonthYear.format(date);
  static String formatShort(DateTime date) => _shortDate.format(date);
  static String formatMonthYear(DateTime date) => _monthYear.format(date);
  static String formatTime(DateTime date) => _time12h.format(date);

  /// Returns friendly relative dates: 'Today', 'Yesterday', or 'dd MMM yyyy'.
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7 && diff > 1) return '$diff days ago';

    return _dayMonthYear.format(date);
  }
}
