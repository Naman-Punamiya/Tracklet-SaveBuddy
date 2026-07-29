import 'package:flutter/material.dart';

abstract class AppSpacing {
  static const double xxSmall = 4.0;
  static const double xSmall = 8.0;
  static const double small = 12.0;
  static const double medium = 16.0;
  static const double large = 20.0;
  static const double xLarge = 24.0;
  static const double xxLarge = 32.0;
  static const double huge = 40.0;

  static const EdgeInsets p4 = EdgeInsets.all(xxSmall);
  static const EdgeInsets p8 = EdgeInsets.all(xSmall);
  static const EdgeInsets p12 = EdgeInsets.all(small);
  static const EdgeInsets p16 = EdgeInsets.all(medium);
  static const EdgeInsets p20 = EdgeInsets.all(large);
  static const EdgeInsets p24 = EdgeInsets.all(xLarge);
  static const EdgeInsets p32 = EdgeInsets.all(xxLarge);

  static const EdgeInsets px16 = EdgeInsets.symmetric(horizontal: medium);
  static const EdgeInsets py8 = EdgeInsets.symmetric(vertical: xSmall);
  static const EdgeInsets py16 = EdgeInsets.symmetric(vertical: medium);
  static const EdgeInsets px16py8 = EdgeInsets.symmetric(horizontal: medium, vertical: xSmall);
  static const EdgeInsets px16py12 = EdgeInsets.symmetric(horizontal: medium, vertical: small);
}
