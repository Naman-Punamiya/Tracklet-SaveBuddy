import 'package:flutter/material.dart';

class CategoryStyle {
  final String monogram;
  final Color bgColor;
  final Color textColor;

  const CategoryStyle({
    required this.monogram,
    required this.bgColor,
    required this.textColor,
  });
}

CategoryStyle getCategoryStyle(String categoryName, bool isCredit) {
  final name = categoryName.trim().toLowerCase();

  if (isCredit || name.contains('income') || name.contains('salary') || name.contains('freelance')) {
    return const CategoryStyle(
      monogram: 'In',
      bgColor: Color(0xFFD1FAE5),
      textColor: Color(0xFF047857),
    );
  }

  if (name.contains('food') || name.contains('dining') || name.contains('restaurant') || name.contains('grocer') || name.contains('cafe')) {
    return const CategoryStyle(
      monogram: 'Fd',
      bgColor: Color(0xFFDCFCE7),
      textColor: Color(0xFF15803D),
    );
  }

  if (name.contains('travel') || name.contains('flight') || name.contains('trip') || name.contains('hotel')) {
    return const CategoryStyle(
      monogram: 'Tr',
      bgColor: Color(0xFFFEF3C7),
      textColor: Color(0xFFB45309),
    );
  }

  if (name.contains('transport') || name.contains('cab') || name.contains('fuel') || name.contains('uber') || name.contains('car')) {
    return const CategoryStyle(
      monogram: 'Tp',
      bgColor: Color(0xFFE0F2FE),
      textColor: Color(0xFF0369A1),
    );
  }

  if (name.contains('health') || name.contains('med') || name.contains('doctor') || name.contains('hosp')) {
    return const CategoryStyle(
      monogram: 'He',
      bgColor: Color(0xFFFFE4E6),
      textColor: Color(0xFFBE123C),
    );
  }

  if (name.contains('shop') || name.contains('cloth') || name.contains('store') || name.contains('buy')) {
    return const CategoryStyle(
      monogram: 'Sh',
      bgColor: Color(0xFFEDE9FE),
      textColor: Color(0xFF6D28D9),
    );
  }

  if (name.contains('util') || name.contains('bill') || name.contains('elec') || name.contains('water') || name.contains('recharge')) {
    return const CategoryStyle(
      monogram: 'Ut',
      bgColor: Color(0xFFCCFBF1),
      textColor: Color(0xFF0F766E),
    );
  }

  if (name.contains('home') || name.contains('rent') || name.contains('house')) {
    return const CategoryStyle(
      monogram: 'Ho',
      bgColor: Color(0xFFE0E7FF),
      textColor: Color(0xFF4338CA),
    );
  }

  if (name.contains('edu') || name.contains('school') || name.contains('course') || name.contains('study') || name.contains('book')) {
    return const CategoryStyle(
      monogram: 'Ed',
      bgColor: Color(0xFFFCE7F3),
      textColor: Color(0xFFBE185D),
    );
  }

  final clean = categoryName.trim();
  String mono = 'Ex';
  if (clean.length >= 2) {
    mono = clean.substring(0, 2).toUpperCase();
  } else if (clean.isNotEmpty) {
    mono = clean.toUpperCase();
  }

  final int hash = clean.hashCode.abs();
  final palettes = [
    [const Color(0xFFDCFCE7), const Color(0xFF15803D)],
    [const Color(0xFFE0F2FE), const Color(0xFF0369A1)],
    [const Color(0xFFFEF3C7), const Color(0xFFB45309)],
    [const Color(0xFFEDE9FE), const Color(0xFF6D28D9)],
    [const Color(0xFFFFE4E6), const Color(0xFFBE123C)],
    [const Color(0xFFCCFBF1), const Color(0xFF0F766E)],
    [const Color(0xFFE0E7FF), const Color(0xFF4338CA)],
  ];
  final pair = palettes[hash % palettes.length];

  return CategoryStyle(
    monogram: mono,
    bgColor: pair[0],
    textColor: pair[1],
  );
}
