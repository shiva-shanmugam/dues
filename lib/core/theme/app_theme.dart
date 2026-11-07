import 'package:flutter/material.dart';

@immutable
class ReceiptTokens extends ThemeExtension<ReceiptTokens> {
  const ReceiptTokens({
    required this.paper,
    required this.ink,
    required this.muted,
    required this.divider,
  });

  static const light = ReceiptTokens(
    paper: Color(0xFFFBFAF6),
    ink: Color(0xFF111111),
    muted: Color(0xFF555555),
    divider: Color(0xFF111111),
  );
  static const dark = ReceiptTokens(
    paper: Color(0xFF121212),
    ink: Color(0xFFF2EFE6),
    muted: Color(0xFFA09B8F),
    divider: Color(0xFFF2EFE6),
  );

  final Color paper;
  final Color ink;
  final Color muted;
  final Color divider;

  @override
  ReceiptTokens copyWith({
    Color? paper,
    Color? ink,
    Color? muted,
    Color? divider,
  }) => ReceiptTokens(
    paper: paper ?? this.paper,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    divider: divider ?? this.divider,
  );

  @override
  ReceiptTokens lerp(covariant ReceiptTokens? other, double t) {
    if (other == null) return this;
    return ReceiptTokens(
      paper: Color.lerp(paper, other.paper, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

extension ReceiptThemeContext on BuildContext {
  ReceiptTokens get receipt =>
      Theme.of(this).extension<ReceiptTokens>() ?? ReceiptTokens.light;
}

// Temporary compatibility tokens while the existing screens are migrated in
// the following staged commits. Receipt widgets use the dynamic theme tokens.
abstract final class DuesColors {
  static const black = Color(0xFF121212);
  static const surface = Color(0xFF121212);
  static const surfaceRaised = Color(0xFF121212);
  static const offWhite = Color(0xFFF2EFE6);
  static const muted = Color(0xFFA09B8F);
  static const outline = Color(0xFFF2EFE6);
  static const gridDot = Color(0xFF121212);
  static const red = Color(0xFFF2EFE6);
}

abstract final class DuesTheme {
  static ThemeData get light => _build(ReceiptTokens.light, Brightness.light);
  static ThemeData get dark => _build(ReceiptTokens.dark, Brightness.dark);

  static ThemeData _build(ReceiptTokens tokens, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: tokens.ink,
          brightness: brightness,
          surface: tokens.paper,
        ).copyWith(
          primary: tokens.ink,
          onPrimary: tokens.paper,
          surface: tokens.paper,
          onSurface: tokens.ink,
          outline: tokens.divider,
          error: tokens.ink,
          onError: tokens.paper,
        );
    final textTheme = base.textTheme.apply(
      fontFamily: 'IBMPlexMono',
      bodyColor: tokens.ink,
      displayColor: tokens.ink,
    );

    return base.copyWith(
      scaffoldBackgroundColor: tokens.paper,
      colorScheme: scheme,
      extensions: [tokens],
      textTheme: textTheme.copyWith(
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.4,
          height: 1.12,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
      iconTheme: IconThemeData(color: tokens.ink, size: 20),
      dividerTheme: DividerThemeData(color: tokens.divider, thickness: 1),
      cardTheme: CardThemeData(
        color: tokens.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: tokens.divider),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: tokens.divider, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.paper,
        modalBackgroundColor: tokens.paper,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          side: BorderSide(color: tokens.divider, width: 2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: tokens.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: tokens.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: tokens.divider, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.ink,
        contentTextStyle: TextStyle(
          color: tokens.paper,
          fontFamily: 'IBMPlexMono',
          fontSize: 12,
        ),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: tokens.ink),
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadePageTransitionsBuilder(),
        },
      ),
    );
  }
}

class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}

extension DuesText on TextTheme {
  TextStyle get receiptHeading => const TextStyle(
    fontFamily: 'IBMPlexMono',
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.12,
    letterSpacing: 2.4,
  );

  TextStyle get receiptTotal => const TextStyle(
    fontFamily: 'IBMPlexMono',
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 1.05,
  );

  TextStyle get receiptLabel => const TextStyle(
    fontFamily: 'IBMPlexMono',
    fontWeight: FontWeight.w600,
    fontSize: 12,
    letterSpacing: 1,
  );

  TextStyle get dotTitle => receiptHeading;
  TextStyle get dotNumber => receiptTotal;
  TextStyle get label => receiptLabel;
}
