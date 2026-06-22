import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rehab_ai/screens/student/home_page.dart';
import 'package:rehab_ai/screens/student/services_page.dart';
import 'package:rehab_ai/screens/student/progress_page.dart';
import 'package:rehab_ai/screens/student/account/profile_page.dart';
import 'package:rehab_ai/services/local_notification_service.dart';
import 'package:rehab_ai/utils/global_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:rehab_ai/theme/rehab_theme.dart';
import 'package:rehab_ai/services/local_notification_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  dynamic _lastNotificationId;
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
          callback: (_) async {
            await _fetchNotifications(myUserId!);

            await LocalNotificationService.showNotification(
              title: 'New Message',
              body: 'You received a new message from your physiotherapist.',
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'Rental_Record',
          callback: (_) async {
            await _fetchNotifications(myUserId!);

            await LocalNotificationService.showNotification(
              title: 'Equipment Update',
              body: 'Your equipment rental status has been updated.',
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Prescribed_Exercise',
          callback: (_) async {
            await _fetchNotifications(myUserId!);

            await LocalNotificationService.showNotification(
              title: 'New Exercise Assigned',
              body: 'Your physiotherapist assigned a new rehabilitation exercise.',
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Session_Log',
          callback: (_) => _fetchNotifications(myUserId!),
        )
        .subscribe();

    // Polling remains as a fallback if a table is not enabled for Realtime.
    _notificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
        final newNotifications = data['notifications'] ?? [];

        GlobalState.notifications.value = newNotifications;

        if (newNotifications.isNotEmpty) {
          final latest = newNotifications.last;
          final latestId =
              latest['notification_id'] ??
                  latest['id'] ??
                  latest['created_at'] ??
                  latest.toString();

          if (_lastNotificationId != null &&
              latestId != _lastNotificationId) {
            await LocalNotificationService.showNotification(
              title: latest['title']?.toString() ?? 'RehabAI Update',
              body: latest['message']?.toString() ??
                  latest['body']?.toString() ??
                  'You have a new notification.',
            );
          }

          _lastNotificationId = latestId;
        }
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
          color: context.rehabSurface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.rehabBorder),
          boxShadow: [
            BoxShadow(
              color: context.isDarkMode
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0x18204A87),
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
            indicatorColor: context.isDarkMode
                ? const Color(0xFF1E3A5F)
                : RehabColors.primaryLight,
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
