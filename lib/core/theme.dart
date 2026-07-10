import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// KLIQ design system — dark-mode-first, Instagram-like, with the
/// signature cyan → pink gradient accent.
class KliqColors {
  KliqColors._();

  static const background = Color(0xFF000000);
  static const surface = Color(0xFF121212);
  static const surfaceElevated = Color(0xFF1E1E1E);
  static const border = Color(0xFF2A2A2A);

  static const cyan = Color(0xFF22D3EE);
  static const pink = Color(0xFFEC4899);
  static const purple = Color(0xFF8B5CF6);

  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);

  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);
  static const live = Color(0xFFEF4444);

  static const gradient = LinearGradient(
    colors: [cyan, purple, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const storyRing = LinearGradient(
    colors: [cyan, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildKliqTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: KliqColors.background,
    colorScheme: const ColorScheme.dark(
      primary: KliqColors.cyan,
      secondary: KliqColors.pink,
      surface: KliqColors.surface,
      error: KliqColors.danger,
    ),
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: KliqColors.textPrimary,
    displayColor: KliqColors.textPrimary,
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: KliqColors.background,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: KliqColors.textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: KliqColors.background,
      selectedItemColor: KliqColors.textPrimary,
      unselectedItemColor: KliqColors.textMuted,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: false,
      showUnselectedLabels: false,
    ),
    dividerTheme: const DividerThemeData(color: KliqColors.border, thickness: 0.5),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KliqColors.surfaceElevated,
      hintStyle: const TextStyle(color: KliqColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: KliqColors.cyan,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: KliqColors.surfaceElevated,
      contentTextStyle: TextStyle(color: KliqColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// The KLIQ wordmark used on splash/entry and app bars.
class KliqWordmark extends StatelessWidget {
  const KliqWordmark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => KliqColors.gradient.createShader(bounds),
      child: Text(
        'KLIQ',
        style: GoogleFonts.orbitron(
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: size * 0.15,
          color: Colors.white,
        ),
      ),
    );
  }
}
