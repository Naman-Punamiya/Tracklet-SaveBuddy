import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CurrencyService {
  static final ValueNotifier<String> currencyNotifier =
      ValueNotifier<String>("USD (\$)");

  static String get currentCurrency => currencyNotifier.value;

  static String get symbol {
    final curr = currencyNotifier.value;
    if (curr.contains('₹') || curr.contains('INR')) return '₹';
    if (curr.contains('€') || curr.contains('EUR')) return '€';
    if (curr.contains('£') || curr.contains('GBP')) return '£';
    return '\$'; // USD, CAD, AUD default
  }

  static String format(num amount) {
    final formattedNum = NumberFormat('#,##,##0.00').format(amount);
    return '$symbol$formattedNum';
  }

  static String formatCompact(num amount) {
    final formattedNum = NumberFormat('#,##,##0').format(amount.toInt());
    return '$symbol$formattedNum';
  }
}
