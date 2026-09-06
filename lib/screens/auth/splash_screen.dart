import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rehab_ai/theme/rehab_theme.dart';
import 'package:rehab_ai/screens/auth/landing_page.dart';
import 'package:rehab_ai/screens/student/main_screen.dart';
import 'package:rehab_ai/screens/physiotherapist/physio_dashboard.dart';
import 'package:rehab_ai/screens/admin/admin_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });

    // Never leave the user on the loading screen indefinitely.
    Future<void>.delayed(const Duration(seconds: 12), () {
      if (mounted && !_hasNavigated) {
        debugPrint('Auth routing timed out; opening the landing page.');
        _navigateToLanding();
      }
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    final sessionUser = Supabase.instance.client.auth.currentUser;
    if (sessionUser == null) {
      _navigateToLanding();
      return;
    }

    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();

      final response = await http
          .get(Uri.parse('$apiUrl/users/profile/${sessionUser.id}'))
          .timeout(const Duration(seconds: 8));

      if (!mounted || _hasNavigated) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['exists'] == true) {
          if (data['is_active'] == false) {
            await _signOutBestEffort();
            _navigateToLanding();
            return;
          }
          final role = data['role'];
          if (!mounted || _hasNavigated) return;
          if (role == 'P') {
            _hasNavigated = true;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => Theme(
                  data: RehabTheme.light,
                  child: const PhysioDashboard(),
                ),
              ),
            );
          } else if (role == 'A') {
            _hasNavigated = true;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => Theme(
                  data: RehabTheme.light,
                  child: const AdminDashboard(),
                ),
              ),
            );
          } else {
            _hasNavigated = true;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          }
        } else {
          // Supabase session exists but profile doesn't exist in backend DB
          await _signOutBestEffort();
          _navigateToLanding();
        }
      } else {
        // Backend returned non-200. Route to landing to be safe.
        _navigateToLanding();
      }
    } catch (e) {
      debugPrint("Auth routing check failed: $e");
      // Network timeout or backend down. Still route to landing page so the user isn't stuck.
      _navigateToLanding();
    }
  }

  Future<void> _signOutBestEffort() async {
    try {
      await Supabase.instance.client.auth
          .signOut()
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Could not clear the saved session during startup: $e');
    }
  }

  void _navigateToLanding() {
    if (mounted && !_hasNavigated) {
      _hasNavigated = true;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LandingPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1565C0),
        ),
      ),
    );
  }
}
