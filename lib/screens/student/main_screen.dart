import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rehab_ai/screens/student/home_page.dart';
import 'package:rehab_ai/screens/student/services_page.dart';
import 'package:rehab_ai/screens/student/progress_page.dart';
import 'package:rehab_ai/screens/student/account/profile_page.dart';
import 'package:rehab_ai/utils/global_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:rehab_ai/theme/rehab_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Timer? _notificationTimer;
  RealtimeChannel? _notificationChannel;
  int? _notificationUserId;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      const HomePage(),
      const ServicesPage(),
      const ProgressPage(),
      const ProfilePage(),
    ];
    _startNotificationPolling();
  }

  void _startNotificationPolling() async {
    final supabase = Supabase.instance.client;
    await Future.delayed(const Duration(milliseconds: 300));
    final user = supabase.auth.currentUser;
    if (user == null) return;

    int? myUserId;
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final userRes = await http.get(
        Uri.parse('$apiUrl/users/profile/${user.id}'),
      );
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        myUserId = userData['user_id'];
      }
    } catch (e) {
      debugPrint('Error fetching user_id: $e');
    }

    if (myUserId == null) return;
    _notificationUserId = myUserId;

    // Fetch immediately
    _fetchNotifications(myUserId);

    _notificationChannel = supabase
        .channel('patient-notifications-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Chat_Log',
          callback: (_) => _fetchNotifications(myUserId!),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'Rental_Record',
          callback: (_) => _fetchNotifications(myUserId!),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Prescribed_Exercise',
          callback: (_) => _fetchNotifications(myUserId!),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Session_Log',
          callback: (_) => _fetchNotifications(myUserId!),
        )
        .subscribe();

    // Polling remains as a fallback if a table is not enabled for Realtime.
    _notificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchNotifications(myUserId!);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _notificationUserId != null) {
      _fetchNotifications(_notificationUserId!);
    }
  }

  Future<void> _fetchNotifications(int userId) async {
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(
        Uri.parse('$apiUrl/users/$userId/notifications'),
      );
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
    WidgetsBinding.instance.removeObserver(this);
    if (_notificationChannel != null) {
      Supabase.instance.client.removeChannel(_notificationChannel!);
    }
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      if (index == 2) {
        _screens[2] = ProgressPage(key: UniqueKey());
      }
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: RehabColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18204A87),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            height: 70,
            elevation: 0,
            backgroundColor: Colors.transparent,
            indicatorColor: RehabColors.primaryLight,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Services',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Progress',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
