import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Show splash animation for at least 3.5 seconds
    await Future.delayed(const Duration(milliseconds: 3500));

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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['exists'] == true) {
          final role = data['role'];
          if (!mounted) return;
          if (role == 'P') {
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          }
        } else {
          // Supabase session exists but profile doesn't exist in backend DB
          await Supabase.instance.client.auth.signOut();
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

  void _navigateToLanding() {
    if (mounted) {
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.3,
            colors: isDarkMode
                ? [
                    const Color(0xFF1A237E).withOpacity(0.4),
                    const Color(0xFF0A0E21),
                  ]
                : [
                    const Color(0xFFE3F2FD),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated glowing Logo Icon
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.health_and_safety_rounded,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // App Title
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'RehabAI',
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // App Subtitle
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'Smart Therapy. Real Results.',
                        style: GoogleFonts.readexPro(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Subtly loading indicator at the bottom
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF1565C0).withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
