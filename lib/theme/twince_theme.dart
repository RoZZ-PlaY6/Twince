import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Saved appearance. Add a value here to offer another theme later.
enum TwinceThemeId {
  midnight,
}

extension TwinceThemeIdX on TwinceThemeId {
  String get storageKey => name;

  String get label => switch (this) {
        TwinceThemeId.midnight => 'Midnight',
      };

  /// Representative color shown beside the theme name.
  Color get swatch => switch (this) {
        TwinceThemeId.midnight => const Color(0xFF0B1738),
      };

  ThemeData get themeData => switch (this) {
        TwinceThemeId.midnight => AppTheme.dark,
      };

  static TwinceThemeId fromStorage(String? value) {
    for (final theme in TwinceThemeId.values) {
      if (theme.storageKey == value) return theme;
    }
    return TwinceThemeId.midnight;
  }
}
