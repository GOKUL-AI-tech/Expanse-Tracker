import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, String currencyCode) {
    final symbol = _getSymbol(currencyCode);
    final formatter = NumberFormat('#,##,##0.00');
    final abs = formatter.format(amount.abs());
    return amount < 0 ? '-$symbol$abs' : '$symbol$abs';
  }

  static String formatCompact(double amount, String currencyCode) {
    final symbol = _getSymbol(currencyCode);
    final abs = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (abs >= 10000000) {
      return '$sign$symbol${(abs / 10000000).toStringAsFixed(2)}Cr';
    } else if (abs >= 100000) {
      return '$sign$symbol${(abs / 100000).toStringAsFixed(2)}L';
    } else if (abs >= 1000) {
      return '$sign$symbol${(abs / 1000).toStringAsFixed(1)}K';
    }
    return format(amount, currencyCode);
  }

  static String _getSymbol(String code) {
    const symbols = {
      'INR': '₹',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'AED': 'د.إ',
      'SGD': 'S\$',
    };
    return symbols[code] ?? code;
  }
}

class DateFormatter {
  static String formatDate(DateTime date) =>
      DateFormat('dd MMM yyyy').format(date);

  static String formatShortDate(DateTime date) =>
      DateFormat('dd MMM').format(date);

  static String formatMonthYear(DateTime date) =>
      DateFormat('MMM yyyy').format(date);

  static String formatYear(DateTime date) => DateFormat('yyyy').format(date);

  static String formatFull(DateTime date) =>
      DateFormat('EEEE, dd MMMM yyyy').format(date);

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
