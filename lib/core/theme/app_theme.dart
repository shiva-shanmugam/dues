import 'package:flutter/material.dart';

abstract final class DuesColors {
  static const black = Color(0xFF000000);
  static const surface = Color(0xFF0A0A0A);
  static const surfaceRaised = Color(0xFF101010);
  static const offWhite = Color(0xFFF5F5F5);
  static const muted = Color(0xFF8E8E8E);
  static const outline = Color(0xFF2B2B2B);
  static const gridDot = Color(0xFF171717);
  static const red = Color(0xFFD71921);
}

abstract final class DuesTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: DuesColors.black,
      colorScheme: const ColorScheme.dark(
        primary: DuesColors.red,
        onPrimary: DuesColors.offWhite,
        surface: DuesColors.surface,
        onSurface: DuesColors.offWhite,
        outline: DuesColors.outline,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'SpaceMono',
        bodyColor: DuesColors.offWhite,
        displayColor: DuesColors.offWhite,
      ),
      iconTheme: const IconThemeData(color: DuesColors.offWhite, size: 21),
      dividerTheme: const DividerThemeData(color: DuesColors.outline),
      splashFactory: NoSplash.splashFactory,
    );
  }
}

extension DuesText on TextTheme {
  TextStyle get dotTitle => const TextStyle(
    fontFamily: 'Doto',
    fontVariations: [FontVariation('wght', 800)],
    fontSize: 34,
    height: 1,
    letterSpacing: -1,
    color: DuesColors.offWhite,
  );

  TextStyle get dotNumber => const TextStyle(
    fontFamily: 'Doto',
    fontVariations: [FontVariation('wght', 900)],
    fontSize: 42,
    height: 1,
    letterSpacing: -1.5,
    color: DuesColors.offWhite,
  );

  TextStyle get label => const TextStyle(
    fontFamily: 'SpaceMono',
    fontWeight: FontWeight.bold,
    fontSize: 11,
    letterSpacing: 1.4,
    color: DuesColors.muted,
  );
}
