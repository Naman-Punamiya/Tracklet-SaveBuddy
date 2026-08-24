import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CurrencyService {
  static final ValueNotifier<String> currencyNotifier =
      ValueNotifier<String>("INR (₹)");

  static String get currentCurrency => currencyNotifier.value;

  static String get symbol {
    final curr = currencyNotifier.value;
    if (curr.contains('₹') || curr.contains('INR')) return '₹';
    if (curr.contains('€') || curr.contains('EUR')) return '€';
    if (curr.contains('£') || curr.contains('GBP')) return '£';
    if (curr.contains('\$') || curr.contains('USD') || curr.contains('CAD') || curr.contains('AUD')) return '\$';
    return '₹'; // Default to Rupee
  }

  static String format(num amount) {
    final double doubleVal = amount.toDouble();
    final formattedNum = NumberFormat('#,##0.00').format(doubleVal);
    return '$symbol$formattedNum';
  }

  static String formatCompact(num amount) {
    final double doubleVal = amount.toDouble();
    final bool hasDecimals = (doubleVal % 1) != 0;
    final String pattern = hasDecimals ? '#,##0.00' : '#,##0';
    final formattedNum = NumberFormat(pattern).format(doubleVal);
    return '$symbol$formattedNum';
  }
}
