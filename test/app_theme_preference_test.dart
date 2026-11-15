import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twince/screens/settings_screen.dart';
import 'package:twince/services/user_preferences_service.dart';
import 'package:twince/theme/app_theme.dart';
import 'package:twince/theme/twince_theme.dart';

void main() {
  final preferences = UserPreferencesService.instance;

  test('missing or unknown theme stays on Midnight', () async {
    SharedPreferences.setMockInitialValues({});
    await preferences.init();
    expect(preferences.appTheme, TwinceThemeId.midnight);

    SharedPreferences.setMockInitialValues({'app_theme': 'sunrise'});
    await preferences.init();
    expect(preferences.appTheme, TwinceThemeId.midnight);
    expect(preferences.appTheme.themeData.colorScheme.brightness,
        AppTheme.dark.colorScheme.brightness);
  });

  test('Midnight remains selected after the preferences reload', () async {
    SharedPreferences.setMockInitialValues({});
    await preferences.init();
    await preferences.saveAppTheme(TwinceThemeId.midnight);
    await preferences.init();

    expect(preferences.appTheme, TwinceThemeId.midnight);
    expect(preferences.appTheme.label, 'Midnight');
    expect(preferences.appTheme.swatch, TwinceThemeId.midnight.swatch);
    expect(preferences.appTheme.themeData.scaffoldBackgroundColor,
        AppTheme.dark.scaffoldBackgroundColor);
  });

  testWidgets('Settings selects Christmas, restores it and returns to Midnight',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await preferences.init();
    final semantics = tester.ensureSemantics();
    PackageInfo.setMockInitialValues(
      appName: 'Twince',
      packageName: 'com.twince.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    Widget app() => ListenableBuilder(
          listenable: preferences,
          builder: (context, _) => MaterialApp(
            theme: preferences.appTheme.themeData,
            home: const Scaffold(body: SettingsScreen()),
          ),
        );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final standard = find.byKey(const ValueKey('theme-section-standard'));
    final special = find.byKey(const ValueKey('theme-section-special'));
    expect(find.descendant(of: standard, matching: find.text('Christmas')),
        findsNothing);
    expect(find.descendant(of: special, matching: find.text('Christmas')),
        findsOneWidget);
    expect(tester.getTopLeft(special).dy,
        greaterThan(tester.getTopLeft(standard).dy));
    await tester.tap(find.text('Midnight'));
    await tester.pumpAndSettle();
    expect(find.text('Christmas'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(PopupMenuButton<dynamic>), findsNothing);
    await tester.ensureVisible(find.text('Christmas'));
    await tester.tap(find.text('Christmas'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(preferences.appTheme, TwinceThemeId.christmas);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Christmas theme')),
      matchesSemantics(
        label: 'Christmas theme',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    expect(
        find.descendant(
            of: special, matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget);
    expect(
        find.descendant(
            of: standard, matching: find.byIcon(Icons.check_rounded)),
        findsNothing);
    expect(
        Theme.of(tester.element(find.byType(SettingsScreen)))
            .scaffoldBackgroundColor,
        Colors.transparent);

    await tester.pumpWidget(const SizedBox());
    await preferences.init();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Christmas'), findsOneWidget);
    expect(preferences.appTheme, TwinceThemeId.christmas);
    expect(
        find.descendant(
            of: special, matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget);

    await tester.ensureVisible(find.text('Midnight'));
    await tester.tap(find.text('Midnight'));
    await tester.pumpAndSettle();
    expect(preferences.appTheme, TwinceThemeId.midnight);
    expect(
        Theme.of(tester.element(find.byType(SettingsScreen)))
            .scaffoldBackgroundColor,
        AppTheme.dark.scaffoldBackgroundColor);
    semantics.dispose();
  });
}
