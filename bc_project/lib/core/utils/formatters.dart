// lib/core/utils/formatters.dart
import 'package:intl/intl.dart';

class AppFormatters {
  static String currency(double amount, {String symbol = '₨', int decimals = 0}) {
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: decimals);
    return formatter.format(amount);
  }

  static String currencyCompact(double amount, {String symbol = '₨'}) {
    if (amount >= 10000000) return '$symbol${(amount / 10000000).toStringAsFixed(2)} Cr';
    if (amount >= 100000) return '$symbol${(amount / 100000).toStringAsFixed(2)} L';
    if (amount >= 1000) return '$symbol${(amount / 1000).toStringAsFixed(1)} K';
    return '$symbol${amount.toStringAsFixed(0)}';
  }

  static String date(DateTime date, {String format = 'dd MMM yyyy'}) =>
      DateFormat(format).format(date);

  static String dateTime(DateTime date) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(date);

  static String monthYear(DateTime date) => DateFormat('MMMM yyyy').format(date);

  static String shortDate(DateTime date) => DateFormat('dd MMM').format(date);

  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return AppFormatters.date(date);
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String monthName(int month) => DateFormat('MMMM').format(DateTime(2024, month));
  static String shortMonthName(int month) => DateFormat('MMM').format(DateTime(2024, month));
}
