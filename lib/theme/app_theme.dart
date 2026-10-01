import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF0B0F19);
  static const surface = Color(0xFF1E293B);
  static const purple = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF06B6D4);
  static const blue = Color(0xFF3B82F6);
  static const completed = Color(0xFF10B981);
  static const failed = Color(0xFFBE5366);

  // Font families
  static const String englishFontFamily = 'Inter';
  static const String persianFontFamily = 'Vazirmatn';

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.dark,
      surface: surface,
    ).copyWith(primary: purple, secondary: cyan, error: failed);

    final baseTextTheme = Typography.englishLike2018.apply(
      fontFamily: englishFontFamily,
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: englishFontFamily,
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: Colors.white,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        toolbarTextStyle: baseTextTheme.bodyMedium,
      ),
      tabBarTheme: TabBarTheme(
        labelStyle: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cyan, width: 1.5),
        ),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(color: Colors.white38),
        labelStyle: baseTextTheme.bodyMedium?.copyWith(color: Colors.white70),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: purple,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: baseTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogTheme(
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        contentTextStyle: baseTextTheme.bodyMedium,
      ),
    );
  }

  static BoxDecoration neonCard({Color accent = purple}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.14), blurRadius: 16)
        ],
      );
}
