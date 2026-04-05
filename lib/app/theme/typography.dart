import 'package:flutter/material.dart';

TextTheme buildTextTheme(TextTheme base) {
  return base.copyWith(
    headlineLarge: base.headlineLarge?.copyWith(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w800,
      fontSize: 32,
      height: 1.2,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w700,
      fontSize: 28,
      height: 1.25,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w700,
      fontSize: 20,
      height: 1.3,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w600,
      fontSize: 16,
      height: 1.35,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w500,
      fontSize: 15,
      height: 1.5,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 1.45,
    ),
    bodySmall: base.bodySmall?.copyWith(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 12,
      height: 1.4,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w700,
      fontSize: 14,
      height: 1.2,
    ),
  );
}
