import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Saved appearance. Add a value here to offer another theme later.
enum TwinceThemeId {
  midnight,
  christmas,
}

enum TwinceThemeCategory { standard, special }

extension TwinceThemeIdX on TwinceThemeId {
  String get storageKey => name;

  TwinceThemeCategory get category => switch (this) {
        TwinceThemeId.midnight => TwinceThemeCategory.standard,
        TwinceThemeId.christmas => TwinceThemeCategory.special,
      };

  String get label => switch (this) {
        TwinceThemeId.midnight => 'Midnight',
        TwinceThemeId.christmas => 'Christmas',
      };

  /// Representative color shown beside the theme name.
  Color get swatch => switch (this) {
        TwinceThemeId.midnight => const Color(0xFF0B1738),
        TwinceThemeId.christmas => const Color(0xFFA78BFA),
      };

  ThemeData get themeData => switch (this) {
        TwinceThemeId.midnight => AppTheme.dark,
        TwinceThemeId.christmas => AppTheme.christmas,
      };

  static TwinceThemeId fromStorage(String? value) {
    for (final theme in TwinceThemeId.values) {
      if (theme.storageKey == value) return theme;
    }
    return TwinceThemeId.midnight;
  }
}
