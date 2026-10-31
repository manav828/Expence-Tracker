import 'package:intl/intl.dart';

/// Reusable utility for formatting currency and monetary amounts.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _inrNoDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _inrWithDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Formats amount as `₹1,250` (or `₹1,250.50` if [decimals] is true or amount has fractional cents).
  static String format(double amount, {bool decimals = false}) {
    if (decimals || (amount % 1 != 0)) {
      return _inrWithDecimals.format(amount);
    }
    return _inrNoDecimals.format(amount);
  }

  /// Formats a compact amount like `₹1.5K` or `₹2.4L`.
  static String formatCompact(double amount) {
    if (amount.abs() >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount.abs() >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount.abs() >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}k';
    }
    return format(amount);
  }
}
