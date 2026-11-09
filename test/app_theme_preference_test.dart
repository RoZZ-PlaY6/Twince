import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}
