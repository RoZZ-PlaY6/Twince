import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';
import '../theme/twince_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _version;
  String? _buildNumber;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  TwinceThemeId get _theme => UserPreferencesService.instance.appTheme;

  Future<void> _selectTheme(TwinceThemeId theme) async {
    await UserPreferencesService.instance.saveAppTheme(theme);
    if (mounted) setState(() {});
  }

  Widget _themeSection(String title, TwinceThemeCategory category) {
    final themes =
        TwinceThemeId.values.where((theme) => theme.category == category);
    return DecoratedBox(
      key: ValueKey('theme-section-${category.name}'),
      decoration: BoxDecoration(
        color: AppTheme.isChristmas(context)
            ? const Color(0xFF211344)
            : const Color(0xFF0B1738),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.cyan.withValues(alpha: 0.14), blurRadius: 16),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 12),
            ThemeOptionsLayout(
              children: [for (final theme in themes) _themeOption(theme)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(TwinceThemeId theme) {
    final selected = _theme == theme;
    void select() => _selectTheme(theme);
    return Semantics(
      label: '${theme.label} theme',
      button: true,
      enabled: true,
      selected: selected,
      onTap: select,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('theme-option-${theme.storageKey}'),
          onTap: select,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: AppTheme.isChristmas(context)
                  ? const Color(0xFF302052)
                  : const Color(0xFF121C36),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppTheme.cyan
                    : AppTheme.cyan.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Expanded(
                    child: Text(theme.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ))),
                const SizedBox(width: 10),
                _ThemeSwatch(
                  key: ValueKey('${theme.storageKey}-theme-swatch'),
                  color: theme.swatch,
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: selected
                      ? const Icon(Icons.check_rounded, color: AppTheme.cyan)
                      : null,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (error) {
      debugPrint('Could not read package info: $error');
      if (!mounted) return;
      setState(() {
        _version = 'unavailable';
        _buildNumber = 'unavailable';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionLabel = _version == null
        ? 'Version …'
        : _version == 'unavailable'
            ? 'Version unavailable'
            : 'Version $_version';
    // Android uses an integer versionCode: its final digit is the displayed
    // minor build component (for example, 11 is displayed as 1.1).
    final rawBuild = _buildNumber;
    final build = rawBuild != null && RegExp(r'^\d{2,}$').hasMatch(rawBuild)
        ? '${rawBuild.substring(0, rawBuild.length - 1)}.${rawBuild.substring(rawBuild.length - 1)}'
        : rawBuild;

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 96 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _themeSection('Theme', TwinceThemeCategory.standard),
              const SizedBox(height: 16),
              _themeSection('Special Theme', TwinceThemeCategory.special),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: AppTheme.isChristmas(context)
                      ? const Color(0xF2211344)
                      : const Color(0xF20B1738),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: AppTheme.cyan.withValues(alpha: 0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cyan.withValues(alpha: 0.14),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.settings_rounded,
                      color: AppTheme.cyan,
                      size: 46,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      versionLabel,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Build number: ${build ?? '…'}',
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '© 2026. All rights reserved.',
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({super.key, required this.color});

  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF9BB0C9)),
        ),
      );
}

/// Wraps options at small widths without changing size when selection changes.
@visibleForTesting
class ThemeOptionsLayout extends StatelessWidget {
  const ThemeOptionsLayout({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final columns =
              ((constraints.maxWidth + gap) / 192).floor().clamp(1, 3);
          final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final child in children) SizedBox(width: width, child: child)
            ],
          );
        },
      );
}
