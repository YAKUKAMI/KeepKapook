import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// สีแบรนด์ KeepKapook
class AppColors {
  static const mint = Color(0xFF52C7A5);
  static const deepGreen = Color(0xFF176B58);
  static const warmYellow = Color(0xFFFFC857);
  static const coral = Color(0xFFFF7B6B);
  static const cream = Color(0xFFFFF9EF);
  static const darkText = Color(0xFF19332D);
  static const mutedText = Color(0xFF6B7D78);
  static const error = Color(0xFFDC4C4C);
  static const white = Color(0xFFFFFFFF);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.mint,
      primary: AppColors.mint,
      secondary: AppColors.warmYellow,
      surface: AppColors.white,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.cream,
  );

  return base.copyWith(
    textTheme: GoogleFonts.promptTextTheme(base.textTheme).apply(
      bodyColor: AppColors.darkText,
      displayColor: AppColors.darkText,
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.mint,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}

// เงาอ่อนสำหรับ card
const kCardShadow = [
  BoxShadow(color: Color(0x0F19332D), blurRadius: 20, offset: Offset(0, 4)),
];
