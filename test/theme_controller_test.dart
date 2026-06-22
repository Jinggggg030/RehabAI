import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';
import 'package:rehab_ai/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dark theme uses the RehabAI dark palette', () {
    final theme = RehabTheme.dark;

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, RehabColors.darkBackground);
    expect(theme.colorScheme.surface, RehabColors.darkSurface);
  });

  test('theme preference is restored and persisted', () async {
    SharedPreferences.setMockInitialValues({'dark_mode_enabled': true});

    await AppThemeController.initialize();
    expect(AppThemeController.themeMode.value, ThemeMode.dark);

    await AppThemeController.setDarkMode(false);
    final preferences = await SharedPreferences.getInstance();
    expect(AppThemeController.themeMode.value, ThemeMode.light);
    expect(preferences.getBool('dark_mode_enabled'), isFalse);
  });
}
