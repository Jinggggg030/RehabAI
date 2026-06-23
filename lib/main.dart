import 'package:flutter/material.dart';
import 'package:rehab_ai/screens/auth/splash_screen.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';
import 'package:rehab_ai/theme/theme_controller.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  await AppThemeController.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.themeMode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'RehabAI',
        debugShowCheckedModeBanner: false,
        theme: RehabTheme.light,
        darkTheme: RehabTheme.dark,
        themeMode: themeMode,
        home: const SplashScreen(),
      ),
    );
  }
}
