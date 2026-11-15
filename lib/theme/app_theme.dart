import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF0B0F19);
  static const surface = Color(0xFF1E293B);
  static const purple = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF06B6D4);
  static const blue = Color(0xFF3B82F6);
  static const completed = Color(0xFF10B981);
  static const failed = Color(0xFFBE5366);

  static bool isChristmas(BuildContext context) =>
      Theme.of(context).colorScheme.primary == const Color(0xFFA78BFA);

  static LinearGradient sheetGradient(BuildContext context) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isChristmas(context)
            ? const [Color(0xF2211344), Color(0xF7120D27)]
            : const [Color(0xF20B1738), Color(0xF7071028)],
      );

  static ThemeData get christmas {
    final base = dark;
    const background = Color(0xFF120D27);
    const surface = Color(0xFF211344);
    const primary = Color(0xFFA78BFA);
    const secondary = Color(0xFF67D5FF);
    const text = Color(0xFFF6F3FF);
    const muted = Color(0xFFC9C4E3);
    final scheme = base.colorScheme.copyWith(
      primary: primary,
      onPrimary: background,
      secondary: secondary,
      onSecondary: background,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: surface,
      cardColor: surface,
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: background),
      dialogTheme: base.dialogTheme.copyWith(backgroundColor: surface),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: surface,
        labelStyle: base.textTheme.bodyMedium?.copyWith(color: muted),
        hintStyle: base.textTheme.bodyMedium?.copyWith(color: muted),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: secondary, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: primary,
        foregroundColor: background,
      ),
    );
  }

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
      tabBarTheme: TabBarThemeData(
        labelStyle:
            baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
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
          textStyle:
              baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle:
              baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle:
              baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle:
              baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle:
            baseTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle:
            baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        contentTextStyle: baseTextTheme.bodyMedium,
      ),
    );
  }

  static BoxDecoration neonCard(
          {Color accent = purple, BuildContext? context}) =>
      BoxDecoration(
        color: context != null && isChristmas(context)
            ? const Color(0xFF211344)
            : surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.14), blurRadius: 16)
        ],
      );
}
