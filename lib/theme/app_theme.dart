// ration_safe_mobile_app/lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds
  static const Color bgPrimary = Color(0xFF0A0E17);
  static const Color bgSecondary = Color(0xFF0F172A);
  static const Color bgCard = Color(0xD8121A2B); // rgba(18, 26, 43, 0.85)
  static const Color bgCardHover = Color(0xF21A253C);

  // Borders
  static const Color borderSubtle = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const Color borderAccent = Color(0x4038BDF8); // rgba(56, 189, 248, 0.25)
  static const Color borderEmerald = Color(0x4010B981);

  // Text
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDim = Color(0xFF64748B);

  // Accents
  static const Color cyan400 = Color(0xFF38BDF8);
  static const Color cyan500 = Color(0xFF06B6D4);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color rose400 = Color(0xFFFB7185);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color purple400 = Color(0xFFC084FC);
  static const Color purple500 = Color(0xFFA855F7);
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo500 = Color(0xFF6366F1);

  // Lifecycle States
  static const Color stateAttempt = cyan400;
  static const Color stateFail = rose500;
  static const Color stateFallback = purple500;
  static const Color stateProvisional = amber500;
  static const Color stateReconciled = emerald500;
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      primaryColor: AppColors.cyan400,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyan400,
        secondary: AppColors.emerald500,
        surface: AppColors.bgSecondary,
        error: AppColors.rose500,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: AppColors.textMain,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: AppColors.textMain,
        displayColor: AppColors.textMain,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgPrimary.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSecondary,
        hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cyan400, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.rose500),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyan500,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  // Glassmorphic Decoration helper
  static BoxDecoration glassCardDecoration({
    Color? borderColor,
    double borderRadius = 14,
    bool glow = false,
  }) {
    return BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? AppColors.borderSubtle,
        width: 1,
      ),
      boxShadow: glow
          ? [
              BoxShadow(
                color: (borderColor ?? AppColors.cyan400).withValues(alpha: 0.15),
                blurRadius: 18,
                spreadRadius: 2,
              )
            ]
          : [
              const BoxShadow(
                color: Color(0x66000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
    );
  }
}
