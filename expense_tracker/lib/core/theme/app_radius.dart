import 'package:flutter/material.dart';

abstract class AppRadius {
  static const double r8 = 8.0;
  static const double r10 = 10.0;
  static const double r12 = 12.0;
  static const double r14 = 14.0;
  static const double r16 = 16.0;
  static const double r18 = 18.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;
  static const double r30 = 30.0;

  static const Radius radius8 = Radius.circular(r8);
  static const Radius radius12 = Radius.circular(r12);
  static const Radius radius16 = Radius.circular(r16);
  static const Radius radius20 = Radius.circular(r20);
  static const Radius radius24 = Radius.circular(r24);

  static final BorderRadius small = BorderRadius.circular(r8);
  static final BorderRadius medium = BorderRadius.circular(r12);
  static final BorderRadius large = BorderRadius.circular(r16);
  static final BorderRadius xLarge = BorderRadius.circular(r20);
  static final BorderRadius dialog = BorderRadius.circular(r24);
  static final BorderRadius pill = BorderRadius.circular(r30);
}
