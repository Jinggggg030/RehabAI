import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/screens/home_page.dart';
import 'package:rehab_ai/screens/services_page.dart';
import 'package:rehab_ai/screens/progress_page.dart';
import 'package:rehab_ai/screens/profile_page.dart';
import 'package:rehab_ai/utils/global_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _startNotificationPolling();
  }

  void _startNotificationPolling() async {
    final supabase = Supabase.instance.client;
    await Future.delayed(const Duration(milliseconds: 300));
    final user = supabase.auth.currentUser;
    if (user == null) return;

    int? myUserId;
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final userRes = await http.get(Uri.parse('$apiUrl/users/profile/${user.id}'));
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        myUserId = userData['user_id'];
      }
    } catch (e) {
      debugPrint('Error fetching user_id: $e');
    }

    if (myUserId == null) return;

    // Fetch immediately
    _fetchNotifications(myUserId);

    // Poll every 30 seconds
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchNotifications(myUserId!);
    });
  }

  Future<void> _fetchNotifications(int userId) async {
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/users/$userId/notifications'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        GlobalState.notifications.value = data['notifications'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  // List of screens for each tab
  final List<Widget> _screens = [
    const HomePage(),
    const ServicesPage(),
    const ProgressPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF207866),
          unselectedItemColor: Colors.black54,
          selectedLabelStyle: GoogleFonts.readexPro(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.readexPro(fontSize: 12),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view),
              label: 'Services',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.square_outlined), // Placeholder for Progress icon from wireframe
              activeIcon: Icon(Icons.square),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
