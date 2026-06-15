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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  RealtimeChannel? _globalNotificationSub;

  @override
  void initState() {
    super.initState();
    _setupGlobalNotifications();
  }

  void _setupGlobalNotifications() async {
    final supabase = Supabase.instance.client;
    
    // Wait slightly to ensure session is fully restored on web refresh
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

    // 1. Initial check for unread messages
    try {
      final activeSessions = await supabase.from('Live_Chat_Session')
        .select('session_id')
        .eq('student_id', myUserId)
        .or('session_status.eq.Active,session_status.eq.Triage')
        .order('created_at', ascending: false);
        
      final prefs = await SharedPreferences.getInstance();
      final lastReadStr = prefs.getString('last_read_chat_timestamp');
      DateTime? lastReadTime;
      if (lastReadStr != null) {
        lastReadTime = DateTime.tryParse(lastReadStr);
      }

      for (var session in activeSessions) {
        final sessionId = session['session_id'];
        final lastMsg = await supabase.from('Chat_Log')
          .select('sender_id, timestamp')
          .eq('session_id', sessionId)
          .order('timestamp', ascending: false)
          .limit(1);
        if (lastMsg.isNotEmpty && lastMsg.first['sender_id'] != myUserId) {
          final msgTimestampStr = lastMsg.first['timestamp'];
          if (msgTimestampStr != null && lastReadTime != null) {
            final msgTime = DateTime.tryParse(msgTimestampStr.toString());
            if (msgTime != null && !msgTime.isAfter(lastReadTime)) {
              continue; // Already read
            }
          }
          GlobalState.hasUnreadLiveChat.value = true;
          break;
        }
      }
    } catch (e) {
      debugPrint("Error checking initial unread: $e");
    }

    // 2. Real-time listener for new messages
    _globalNotificationSub = supabase.channel('public:Chat_Log:notifications_patient')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'Chat_Log',
        callback: (payload) {
          final newRow = payload.newRecord;
          if (newRow['sender_id'] != myUserId) {
             GlobalState.hasUnreadLiveChat.value = true;
          }
        }
      ).subscribe();
  }

  @override
  void dispose() {
    if (_globalNotificationSub != null) Supabase.instance.client.removeChannel(_globalNotificationSub!);
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
