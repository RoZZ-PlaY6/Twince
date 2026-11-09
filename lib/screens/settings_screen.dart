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

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  TwinceThemeId get _theme => UserPreferencesService.instance.appTheme;

  Future<void> _chooseTheme() async {
    final picked = await showDialog<TwinceThemeId>(
      context: context,
      builder: (dialogContext) => _ThemeSelectorDialog(selected: _theme),
    );
    if (picked == null) return;
    await UserPreferencesService.instance.saveAppTheme(picked);
    if (mounted) setState(() {});
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = info.version);
    } catch (error) {
      debugPrint('Could not read package info: $error');
      if (!mounted) return;
      setState(() => _version = 'unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionLabel = _version == null
        ? 'Version …'
        : _version == 'unavailable'
            ? 'Version unavailable'
            : 'Version $_version';

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 96 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1738),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.cyan.withValues(alpha: 0.85),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cyan.withValues(alpha: 0.14),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Theme',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _chooseTheme,
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: const Color(0xFF121C36),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.cyan),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    _theme.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _ThemeSwatch(
                                    key:
                                        const ValueKey('midnight-theme-swatch'),
                                    color: _theme.swatch,
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.check_rounded,
                                      color: AppTheme.cyan),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xF20B1738),
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
  const _ThemeSwatch({super.key, required this.color, this.size = 18});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF9BB0C9)),
        ),
      );
}

class _ThemeSelectorDialog extends StatelessWidget {
  const _ThemeSelectorDialog({required this.selected});

  final TwinceThemeId selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0B1738),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF22D3EE)),
      ),
      title: const Text('Theme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final theme in TwinceThemeId.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(theme.label),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThemeSwatch(color: theme.swatch, size: 22),
                  if (theme == selected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_rounded, color: AppTheme.cyan),
                  ],
                ],
              ),
              selected: theme == selected,
              onTap: () => Navigator.pop(context, theme),
            ),
        ],
      ),
    );
  }
}
