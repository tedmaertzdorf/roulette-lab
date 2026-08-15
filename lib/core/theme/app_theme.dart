import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color deepGreenBlack = Color(0xFF08110E);
  static const Color darkSurface = Color(0xFF12201B);
  static const Color darkSurfaceHigh = Color(0xFF1B2B25);
  static const Color rouletteGreen = Color(0xFF2E9B68);
  static const Color rouletteRed = Color(0xFFC74444);
  static const Color rouletteBlack = Color(0xFF15191C);
  static const Color gold = Color(0xFFD6B25E);
  static const Color warmWhite = Color(0xFFF4F1E8);

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: const ColorScheme.dark(
      primary: rouletteGreen,
      onPrimary: Colors.white,
      secondary: gold,
      onSecondary: Color(0xFF2D2308),
      surface: darkSurface,
      onSurface: warmWhite,
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    ),
    scaffold: deepGreenBlack,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: const ColorScheme.light(
      primary: Color(0xFF176B47),
      secondary: Color(0xFF785900),
      onSecondary: Colors.white,
      surface: Color(0xFFFFFBF3),
      onSurface: Color(0xFF18221D),
      error: Color(0xFFBA1A1A),
    ),
    scaffold: const Color(0xFFF6F1E7),
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
  }) {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'RouletteSans',
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'RouletteSans',
        fontFamilyFallback: const <String>['RouletteSymbols'],
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: 'RouletteSans',
        fontFamilyFallback: const <String>['RouletteSymbols'],
      ),
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.dark ? 0 : 1,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scaffold,
        indicatorColor: scheme.primaryContainer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffold,
        indicatorColor: scheme.primaryContainer,
        height: 72,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }
}
