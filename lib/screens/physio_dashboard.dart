import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rehab_ai/screens/login_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/screens/record_session_dialog.dart';
import 'package:rehab_ai/screens/physio_progress_tab.dart';
import '../services/teleconference_service.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';
import 'package:rehab_ai/widgets/portal_backdrop.dart';
import 'package:intl/intl.dart';

class PhysioDashboard extends StatefulWidget {
  const PhysioDashboard({super.key});

  @override
  State<PhysioDashboard> createState() => _PhysioDashboardState();
}

class _PhysioDashboardState extends State<PhysioDashboard> {
  final _supabase = Supabase.instance.client;
  int? _myUserId;
  int _selectedIndex = 0;

  List<int> _assignedSessionIds = [];
  Set<String> _unreadChats = {};
  RealtimeChannel? _globalNotificationSub;
  List<dynamic> _notifications = [];
  Timer? _notificationTimer;
  Set<String> _knownNotificationIds = {};
  bool _notificationsInitialized = false;
  bool _notificationFetchInProgress = false;
  int _pageRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final apiUrl = kIsWeb
        ? 'http://127.0.0.1:8000'
        : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    final userRes = await http.get(
      Uri.parse('$apiUrl/users/profile/${user.id}'),
    );

    if (userRes.statusCode == 200) {
      final userData = jsonDecode(userRes.body);
      if (userData['exists'] == true) {
        setState(() {
          _myUserId = userData['user_id'];
        });
        _fetchAssignedSessions();
        _setupGlobalNotifications();
        _fetchPhysioNotifications();
        _notificationTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _fetchPhysioNotifications(),
        );
      }
    }
  }

  Future<void> _fetchAssignedSessions() async {
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/physio/chats/$_myUserId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _assignedSessionIds = (data['chats'] as List)
              .map((c) => c['session_id'] as int)
              .toList();
          _unreadChats.clear();
          for (var c in data['chats']) {
            if (c['has_unread'] == true) {
              _unreadChats.add(c['session_id'].toString());
            }
          }
        });
      }
    } catch (e) {}
  }

  void _setupGlobalNotifications() {
    _globalNotificationSub = _supabase
        .channel('public:Chat_Log:notifications_global')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Chat_Log',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['sender_id'] != null &&
                newRecord['sender_id'] != _myUserId) {
              final sessionId = newRecord['session_id'] as int;
              if (_assignedSessionIds.contains(sessionId)) {
                setState(() {
                  _unreadChats.add(sessionId.toString());
                });
                _fetchPhysioNotifications(showSnackBar: false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("New message received from patient!"),
                      duration: Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'Live_Chat_Session',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['therapist_id'] == _myUserId &&
                newRecord['session_status'] == 'Active') {
              final sessionId = newRecord['session_id'] as int;
              if (!_assignedSessionIds.contains(sessionId)) {
                _fetchAssignedSessions(); // Fetch again to update assignments and unread status
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("New chat assigned to you!"),
                      duration: Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Rental_Record',
          callback: (_) => _fetchPhysioNotifications(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Appointment',
          callback: (_) => _fetchPhysioNotifications(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Session_Log',
          callback: (_) => _fetchPhysioNotifications(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'Session_Log',
          callback: (_) => _fetchPhysioNotifications(),
        )
        .subscribe();
  }

  Future<void> _fetchPhysioNotifications({bool showSnackBar = true}) async {
    if (_myUserId == null || _notificationFetchInProgress) return;
    _notificationFetchInProgress = true;
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final response = await http.get(
        Uri.parse('$apiUrl/physio/$_myUserId/notifications'),
      );
      if (response.statusCode == 200 && mounted) {
        final fetched = List<dynamic>.from(
          jsonDecode(response.body)['notifications'] ?? [],
        );
        final fetchedIds = fetched
            .map((notification) => notification['notification_id'].toString())
            .toSet();
        final newNotifications = _notificationsInitialized
            ? fetched
                  .where(
                    (notification) => !_knownNotificationIds.contains(
                      notification['notification_id'].toString(),
                    ),
                  )
                  .toList()
            : <dynamic>[];
        final unreadChatIds = fetched
            .where((notification) => notification['type'] == 'chat')
            .map((notification) => notification['reference_id'].toString())
            .toSet();
        final shouldRefreshCurrentPage = newNotifications.any(
          (notification) =>
              (notification['type'] == 'exercise' && _selectedIndex == 1) ||
              (notification['type'] == 'appointment' && _selectedIndex == 2) ||
              (notification['type'] == 'rental' && _selectedIndex == 3),
        );
        setState(() {
          _notifications = fetched;
          _unreadChats = unreadChatIds;
          _knownNotificationIds = fetchedIds;
          _notificationsInitialized = true;
          if (shouldRefreshCurrentPage) _pageRefreshVersion++;
        });
        if (showSnackBar && newNotifications.isNotEmpty && mounted) {
          final notification = newNotifications.first;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  notification['message']?.toString() ??
                      'You have a new update.',
                ),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      }
    } catch (error) {
      debugPrint('Unable to fetch physiotherapist notifications: $error');
    } finally {
      _notificationFetchInProgress = false;
    }
  }

  void _refreshCurrentPage() {
    setState(() => _pageRefreshVersion++);
    _fetchAssignedSessions();
    _fetchPhysioNotifications(showSnackBar: false);
  }

  bool _hasNotification(String type) =>
      _notifications.any((notification) => notification['type'] == type);

  Future<void> _openDashboardSection(int index) async {
    final type = switch (index) {
      1 => 'exercise',
      2 => 'appointment',
      3 => 'rental',
      _ => null,
    };
    final notificationsToRead = type == null
        ? <dynamic>[]
        : _notifications
              .where((notification) => notification['type'] == type)
              .toList();
    setState(() {
      _selectedIndex = index;
      if (type != null) {
        _notifications = _notifications
            .where((notification) => notification['type'] != type)
            .toList();
      }
    });

    if (_myUserId == null) return;
    final apiUrl = kIsWeb
        ? 'http://127.0.0.1:8000'
        : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    for (final notification in notificationsToRead) {
      try {
        await http.post(
          Uri.parse('$apiUrl/users/$_myUserId/notifications/read'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'notification_id': notification['notification_id'],
          }),
        );
      } catch (error) {
        debugPrint('Unable to mark dashboard notification read: $error');
      }
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    if (_globalNotificationSub != null)
      _supabase.removeChannel(_globalNotificationSub!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compactNavigation = MediaQuery.sizeOf(context).width < 1400;
    return Scaffold(
      backgroundColor: RehabColors.portalBackground,
      body: PortalBackdrop(
        accent: RehabColors.primary,
        child: Row(
          children: [
            Container(
              width: compactNavigation ? 82 : 236,
              margin: EdgeInsets.all(compactNavigation ? 10 : 14),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: RehabColors.darkGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: RehabColors.primary.withValues(alpha: 0.20),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _portalBrand(
                    accent: RehabColors.physio,
                    role: 'Physio Portal',
                    compact: compactNavigation,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _portalNavItem(
                          0,
                          Icons.forum_outlined,
                          'Live Chat',
                          compact: compactNavigation,
                          showBadge:
                              _unreadChats.isNotEmpty ||
                              _hasNotification('chat'),
                        ),
                        _portalNavItem(
                          1,
                          Icons.insights_outlined,
                          'Patient Progress',
                          compact: compactNavigation,
                          showBadge: _hasNotification('exercise'),
                        ),
                        _portalNavItem(
                          2,
                          Icons.calendar_month_outlined,
                          'Appointments',
                          compact: compactNavigation,
                          showBadge: _hasNotification('appointment'),
                        ),
                        _portalNavItem(
                          3,
                          Icons.medical_services_outlined,
                          'Equipment',
                          compact: compactNavigation,
                          showBadge: _hasNotification('rental'),
                        ),
                      ],
                    ),
                  ),
                  if (!compactNavigation)
                    const PortalSystemStatus(label: 'Clinical network online')
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Tooltip(
                        message: 'Clinical network online',
                        child: Icon(
                          Icons.circle,
                          color: Color(0xFF4ADE80),
                          size: 9,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton.icon(
                      onPressed: () async {
                        await _supabase.auth.signOut();
                        if (mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: compactNavigation
                          ? const SizedBox.shrink()
                          : const Text('Exit Portal'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        minimumSize: const Size(double.infinity, 46),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 82,
                    margin: const EdgeInsets.fromLTRB(0, 14, 14, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: RehabColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: RehabColors.primary.withValues(alpha: 0.08),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                const [
                                  'Live Chat',
                                  'Patient Progress',
                                  'Appointments',
                                  'Equipment Rentals',
                                ][_selectedIndex],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 12,
                                    color: RehabColors.cyan,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'CLINICAL COMMAND CENTER',
                                    style: TextStyle(
                                      fontSize: 9,
                                      letterSpacing: 1.1,
                                      color: RehabColors.subtle,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!compactNavigation)
                          PortalMetric(
                            icon: Icons.notifications_active_outlined,
                            value: '${_notifications.length}',
                            label: 'NEW UPDATES',
                            accent: RehabColors.cyan,
                          )
                        else
                          Badge.count(
                            count: _notifications.length,
                            isLabelVisible: _notifications.isNotEmpty,
                            child: const Icon(
                              Icons.notifications_active_outlined,
                              color: RehabColors.cyan,
                            ),
                          ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          tooltip: 'Refresh current page',
                          onPressed: _refreshCurrentPage,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        const SizedBox(width: 10),
                        if (!compactNavigation)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: RehabColors.border),
                            ),
                            child: const Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: RehabColors.physio,
                                  child: Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Physiotherapist',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ColoredBox(
                          color: Colors.white,
                          child: _buildMainContent(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _portalBrand({
    required Color accent,
    required String role,
    required bool compact,
  }) {
    return Container(
      height: 74,
      padding: EdgeInsets.symmetric(horizontal: compact ? 15 : 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 11),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RehabAI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white60,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _portalNavItem(
    int index,
    IconData icon,
    String label, {
    bool showBadge = false,
    bool compact = false,
  }) {
    final selected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: () => _openDashboardSection(index),
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Tooltip(
                  message: compact ? label : '',
                  child: Icon(
                    icon,
                    size: 19,
                    color: selected ? Colors.cyanAccent : Colors.white54,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected ? Colors.white : Colors.white60,
                      ),
                    ),
                  ),
                ],
                if (showBadge)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: RehabColors.danger,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: RehabColors.danger.withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_myUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_selectedIndex) {
      case 0:
        return PhysioLiveChatTab(
          key: ValueKey('chat-$_pageRefreshVersion'),
          myUserId: _myUserId!,
          unreadChats: _unreadChats,
          onChatRead: (sessionId) {
            setState(() {
              _unreadChats.remove(sessionId);
              _notifications = _notifications.where((notification) {
                return notification['type'] != 'chat' ||
                    notification['reference_id'].toString() != sessionId;
              }).toList();
            });
          },
        );
      case 1:
        return PhysioProgressTab(
          key: ValueKey('progress-$_pageRefreshVersion'),
          physioId: _myUserId!,
        );
      case 2:
        return PhysioAppointmentsTab(
          key: ValueKey('appointments-$_pageRefreshVersion'),
          myUserId: _myUserId!,
        );
      case 3:
        return PhysioRentalsTab(
          key: ValueKey('rentals-$_pageRefreshVersion'),
          myUserId: _myUserId!,
        );
      default:
        return const Center(child: Text('Unknown Tab'));
    }
  }
}

// ---------------------------------------------------------------------------
// TAB 1: LIVE CHAT
// ---------------------------------------------------------------------------
class PhysioLiveChatTab extends StatefulWidget {
  final int myUserId;
  final Set<String> unreadChats;
  final Function(String) onChatRead;

  const PhysioLiveChatTab({
    super.key,
    required this.myUserId,
    required this.unreadChats,
    required this.onChatRead,
  });

  @override
  State<PhysioLiveChatTab> createState() => _PhysioLiveChatTabState();
}

class _PhysioLiveChatTabState extends State<PhysioLiveChatTab> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _chats = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedChat;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchChats();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchChats(isBackground: true),
    );
  }

  Future<void> _fetchChats({bool isBackground = false}) async {
    if (!isBackground) setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(
        Uri.parse('$apiUrl/physio/chats/${widget.myUserId}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _chats = data['chats'] ?? [];
            // Update selected chat if it was modified
            if (_selectedChat != null) {
              final updated = _chats
                  .where((c) => c['session_id'] == _selectedChat!['session_id'])
                  .toList();
              if (updated.isNotEmpty) _selectedChat = updated.first;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching chats: $e");
    } finally {
      if (!isBackground && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markChatRead(int sessionId) async {
    widget.onChatRead(sessionId.toString());
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      await http.post(
        Uri.parse(
          '$apiUrl/physio/chats/$sessionId/read'
          '?physio_id=${widget.myUserId}',
        ),
      );
    } catch (error) {
      debugPrint('Unable to mark chat as read: $error');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeChats = _chats
        .where((c) => c['session_status'] != 'Closed')
        .toList();
    final pastChats = _chats
        .where((c) => c['session_status'] == 'Closed')
        .toList();

    final compact = MediaQuery.sizeOf(context).width < 1400;
    return Row(
      children: [
        // Left Sidebar: Chat List
        Container(
          width: compact ? 270 : 320,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.black12)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Assigned Chats",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchChats,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _chats.isEmpty
                    ? const Center(
                        child: Text(
                          "No patients assigned yet.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView(
                        children: [
                          if (activeChats.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "ACTIVE CHATS",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ...activeChats.map((chat) {
                            final isSelected =
                                _selectedChat?['session_id'] ==
                                chat['session_id'];
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.blue[50],
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.blue,
                                ),
                              ),
                              title: Text(
                                chat['student_name'] ?? 'Unknown Patient',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text("${chat['discipline']}"),
                              trailing:
                                  widget.unreadChats.contains(
                                    chat['session_id'].toString(),
                                  )
                                  ? Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedChat = chat;
                                });
                                _markChatRead(chat['session_id'] as int);
                              },
                            );
                          }),
                          if (pastChats.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(8, 16, 8, 8),
                              child: Text(
                                "PAST CONVERSATIONS",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ...pastChats.map((chat) {
                            final isSelected =
                                _selectedChat?['session_id'] ==
                                chat['session_id'];
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.grey[200],
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[300],
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                ),
                              ),
                              title: Text(
                                chat['student_name'] ?? 'Unknown Patient',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              subtitle: const Text(
                                "Closed",
                                style: TextStyle(color: Colors.grey),
                              ),
                              onTap: () => setState(() => _selectedChat = chat),
                            );
                          }),
                        ],
                      ),
              ),
            ],
          ),
        ),

        // Right Main Area: Chat Interface
        Expanded(
          child: _selectedChat == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Select a patient to start messaging",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : PhysioChatInterface(
                  sessionId: _selectedChat!['session_id'],
                  myUserId: widget.myUserId,
                  studentName:
                      _selectedChat!['student_name']?.toString() ?? 'Patient',
                  triageData: _selectedChat!['triage_data'],
                  teleconferenceStatus: _selectedChat!['teleconference_status']
                      ?.toString(),
                  isClosed: _selectedChat!['session_status'] == 'Closed',
                  onChatClosed: _fetchChats,
                ),
        ),
      ],
    );
  }
}

class PhysioChatInterface extends StatefulWidget {
  final int sessionId;
  final int myUserId;
  final String studentName;
  final dynamic triageData;
  final String? teleconferenceStatus;
  final bool isClosed;
  final VoidCallback onChatClosed;

  const PhysioChatInterface({
    super.key,
    required this.sessionId,
    required this.myUserId,
    required this.studentName,
    required this.triageData,
    required this.isClosed,
    required this.onChatClosed,
    this.teleconferenceStatus,
  });

  @override
  State<PhysioChatInterface> createState() => _PhysioChatInterfaceState();
}

class _PhysioChatInterfaceState extends State<PhysioChatInterface> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  RealtimeChannel? _subscription;
  bool _isLoading = true;

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadMessagesAndSubscribe();
  }

  @override
  void didUpdateWidget(covariant PhysioChatInterface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _loadMessagesAndSubscribe();
    }
  }

  Future<void> _loadMessagesAndSubscribe() async {
    setState(() => _isLoading = true);
    if (_subscription != null) await _supabase.removeChannel(_subscription!);

    try {
      final res = await _supabase
          .from('Chat_Log')
          .select()
          .eq('session_id', widget.sessionId)
          .order('timestamp', ascending: true);
      setState(() => _messages = List<dynamic>.from(res));
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error loading messages: $e");
    } finally {
      setState(() => _isLoading = false);
    }

    _subscription = _supabase
        .channel('public:Chat_Log:session_${widget.sessionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Chat_Log',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: widget.sessionId,
          ),
          callback: (payload) {
            setState(() => _messages.add(payload.newRecord));
            _scrollToBottom();
          },
        )
        .subscribe();
  }

  Future<void> _startTeleconference() async {
    if (widget.isClosed) return;
    final apiUrl = kIsWeb
        ? 'http://127.0.0.1:8000'
        : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/physio/chats/${widget.sessionId}/teleconference'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'physio_id': widget.myUserId}),
      );
      if (response.statusCode != 200) throw Exception(response.body);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final room = data['meeting_room']?.toString();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video invitation sent to the student.')),
      );
      await TeleconferenceService.join(context: context, meetingRoom: room);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to start the video consultation.'),
          ),
        );
      }
    }
  }

  Future<void> _showPrescriptionForm() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => RecordSessionDialog(
        appointment: {'student_name': widget.studentName},
        chatSessionId: widget.sessionId,
        physioId: widget.myUserId,
      ),
    );
    if (saved == true) widget.onChatClosed();
  }

  Future<void> _sendMessage() async {
    if (widget.isClosed) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      await http.post(
        Uri.parse('$apiUrl/chat/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "session_id": widget.sessionId,
          "user_id": widget.myUserId,
          "message": text,
        }),
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  Future<void> _endChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("End Conversation?"),
        content: const Text(
          "Are you sure you want to close this chat? You will not be able to send any more messages.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("End Chat"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.put(
        Uri.parse('$apiUrl/physio/chats/${widget.sessionId}/close'),
      );
      if (res.statusCode == 200) {
        widget.onChatClosed(); // Refresh the list
      } else {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Failed to end chat")));
      }
    } catch (e) {
      debugPrint("Error ending chat: $e");
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_subscription != null) _supabase.removeChannel(_subscription!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Conversation",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (!widget.isClosed)
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _startTeleconference,
                      icon: const Icon(Icons.video_call_outlined, size: 18),
                      label: Text(
                        widget.teleconferenceStatus == null
                            ? 'Teleconference'
                            : 'Call: ${widget.teleconferenceStatus}',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showPrescriptionForm,
                      icon: const Icon(
                        Icons.medical_information_outlined,
                        size: 18,
                      ),
                      label: const Text('Record Prescription'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _endChat,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text("End Chat"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ],
                )
              else
                Chip(
                  label: const Text(
                    "Closed",
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.grey[600],
                ),
            ],
          ),
        ),
        if (widget.triageData != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.yellow[50],
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AI Triage Summary",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Area: ${widget.triageData['pain_area'] ?? 'Unknown'} | Severity: ${widget.triageData['severity'] ?? 'Unknown'} | Duration: ${widget.triageData['duration'] ?? 'Unknown'}",
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['sender_id'] == widget.myUserId;
                    final isSystem = msg['sender_id'] == null;
                    final meetingRoom = TeleconferenceService.roomFromInvite(
                      msg['content']?.toString(),
                    );
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : (isSystem
                                ? Alignment.center
                                : Alignment.centerLeft),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blue[600]
                              : (isSystem ? Colors.grey[300] : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.5,
                        ),
                        child: meetingRoom == null
                            ? Text(
                                msg['content'] ?? '',
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white
                                      : (isSystem
                                            ? Colors.black54
                                            : Colors.black87),
                                  fontStyle: isSystem
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Video consultation invitation sent.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => TeleconferenceService.join(
                                      context: context,
                                      meetingRoom: meetingRoom,
                                    ),
                                    icon: const Icon(Icons.video_call_outlined),
                                    label: const Text('Rejoin'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
        ),
        if (!widget.isClosed)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.blue[800],
                  elevation: 0,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            width: double.infinity,
            alignment: Alignment.center,
            child: const Text(
              "This conversation has ended.",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2: PATIENT PROGRESS
// ---------------------------------------------------------------------------
class PhysioPatientsTab extends StatefulWidget {
  final int myUserId;
  const PhysioPatientsTab({super.key, required this.myUserId});

  @override
  State<PhysioPatientsTab> createState() => _PhysioPatientsTabState();
}

class _PhysioPatientsTabState extends State<PhysioPatientsTab> {
  List<dynamic> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(
        Uri.parse('$apiUrl/physio/patients/${widget.myUserId}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _patients = data['patients'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching patients: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_patients.isEmpty)
      return const Center(child: Text("No patients assigned."));

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final p = _patients[index];
        final exercises = p['exercises'] as List<dynamic>? ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green[100],
                      child: const Icon(Icons.person, color: Colors.green),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['student_name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            p['email'] ?? '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (p['active_prescription'] != null) ...[
                  Text(
                    "Diagnosis: ${p['active_prescription']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (exercises.isEmpty)
                    const Text(
                      "No exercises assigned yet.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ...exercises.map(
                    (ex) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.fitness_center,
                        color: Colors.black54,
                      ),
                      title: Text(ex['name']),
                      subtitle: Text(
                        "Sets: ${ex['assigned_sets']} | Eval: ${ex['evaluation'] ?? 'None'}",
                      ),
                    ),
                  ),
                ] else ...[
                  const Text(
                    "No active prescription.",
                    style: TextStyle(
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 3: APPOINTMENTS
// ---------------------------------------------------------------------------
class PhysioAppointmentsTab extends StatefulWidget {
  final int myUserId;
  const PhysioAppointmentsTab({super.key, required this.myUserId});

  @override
  State<PhysioAppointmentsTab> createState() => _PhysioAppointmentsTabState();
}

class _PhysioAppointmentsTabState extends State<PhysioAppointmentsTab> {
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _visibleAppointments {
    final query = _searchTerm.trim().toLowerCase();
    final visible = query.isEmpty
        ? List<dynamic>.from(_appointments)
        : _appointments.where((appointment) {
            final name =
                appointment['student_name']?.toString().toLowerCase() ?? '';
            final matric =
                appointment['matric_no']?.toString().toLowerCase() ?? '';
            return name.contains(query) || matric.contains(query);
          }).toList();
    visible.sort((a, b) {
      final aScheduled = a['status'] == 'Scheduled';
      final bScheduled = b['status'] == 'Scheduled';
      if (aScheduled != bScheduled) return aScheduled ? -1 : 1;
      final aDate = DateTime.tryParse(a['schedule_time']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['schedule_time']?.toString() ?? '');
      if (aDate == null || bDate == null) return 0;
      return aScheduled ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    });
    return visible;
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(
        Uri.parse('$apiUrl/physio/appointments/${widget.myUserId}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _appointments = data['appointments'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching appointments: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showRecordSessionDialog(
    Map<String, dynamic> appointment,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RecordSessionDialog(appointment: appointment),
    );
    if (result == true) {
      _fetchAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Session recorded successfully!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showTransferDialog(Map<String, dynamic> appointment) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(
        Uri.parse('$apiUrl/physiotherapists/colleagues/${widget.myUserId}'),
      );

      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final colleagues = data['colleagues'] as List<dynamic>? ?? [];

        if (colleagues.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "No colleagues with the same specialization found.",
                ),
              ),
            );
          }
          return;
        }

        int? selectedColleagueId = colleagues.first['therapist_id'];

        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return AlertDialog(
                    title: const Text("Transfer Appointment"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Select a colleague to transfer this appointment to:",
                        ),
                        const SizedBox(height: 16),
                        DropdownButton<int>(
                          isExpanded: true,
                          value: selectedColleagueId,
                          items: colleagues.map<DropdownMenuItem<int>>((c) {
                            return DropdownMenuItem<int>(
                              value: c['therapist_id'],
                              child: Text(
                                "${c['name']} (${c['specialization']})",
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedColleagueId = val;
                            });
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (selectedColleagueId == null) return;
                          try {
                            final transRes = await http.put(
                              Uri.parse(
                                '$apiUrl/appointments/${appointment['appointment_id']}/transfer',
                              ),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                "new_therapist_id": selectedColleagueId,
                              }),
                            );
                            if (transRes.statusCode == 200) {
                              if (mounted) Navigator.pop(dialogContext);
                              _fetchAppointments();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Appointment transferred successfully!",
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint("Transfer error: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Confirm Transfer"),
                      ),
                    ],
                  );
                },
              );
            },
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Pop loading dialog on error
      debugPrint("Error fetching colleagues: $e");
    }
  }

  Future<void> _showApplyLeaveDialog() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue.shade800),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(
        Uri.parse('$apiUrl/physiotherapists/colleagues/${widget.myUserId}'),
      );

      if (!mounted) return;
      Navigator.pop(context); // Pop loading

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final colleagues = data['colleagues'] as List<dynamic>? ?? [];

        if (colleagues.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("No colleagues available to cover."),
              ),
            );
          }
          return;
        }

        int? selectedColleagueId = colleagues.first['therapist_id'];

        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return AlertDialog(
                    title: const Text("Set Unavailable Dates"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Unavailable Period: ${picked.start.toLocal().toString().split(' ')[0]} to ${picked.end.toLocal().toString().split(' ')[0]}",
                        ),
                        const SizedBox(height: 16),
                        const Text("Select a covering colleague:"),
                        const SizedBox(height: 8),
                        DropdownButton<int>(
                          isExpanded: true,
                          value: selectedColleagueId,
                          items: colleagues.map<DropdownMenuItem<int>>((c) {
                            return DropdownMenuItem<int>(
                              value: c['therapist_id'],
                              child: Text(
                                "${c['name']} (${c['specialization']})",
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedColleagueId = val;
                            });
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (selectedColleagueId == null) return;
                          try {
                            final leaveRes = await http.put(
                              Uri.parse(
                                '$apiUrl/physio/leave/${widget.myUserId}',
                              ),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                "start_date": picked.start
                                    .toUtc()
                                    .toIso8601String(),
                                "end_date": picked.end
                                    .toUtc()
                                    .toIso8601String(),
                                "cover_colleague_id": selectedColleagueId,
                              }),
                            );
                            if (leaveRes.statusCode == 200) {
                              if (mounted) Navigator.pop(dialogContext);
                              _fetchAppointments();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Unavailable dates set & appointments transferred!",
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint("Leave error: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Confirm"),
                      ),
                    ],
                  );
                },
              );
            },
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error: $e");
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    final triage = appointment['triage_data'] is Map
        ? Map<String, dynamic>.from(appointment['triage_data'] as Map)
        : <String, dynamic>{};
    final scheduledAt = DateTime.tryParse(
      appointment['schedule_time']?.toString() ?? '',
    )?.toLocal();
    final isScheduled = appointment['status'] == 'Scheduled';
    final now = DateTime.now();
    final isToday =
        scheduledAt != null &&
        scheduledAt.year == now.year &&
        scheduledAt.month == now.month &&
        scheduledAt.day == now.day;

    Widget detailTile(IconData icon, String label, dynamic rawValue) {
      final value = rawValue?.toString().trim();
      return Container(
        width: 190,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: RehabColors.primaryLight,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: RehabColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: RehabColors.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      letterSpacing: 0.8,
                      color: RehabColors.subtle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value == null || value.isEmpty ? 'Not recorded' : value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: RehabColors.primary.withValues(alpha: 0.20),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    gradient: RehabColors.darkGradient,
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white12,
                        child: Icon(Icons.person_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment['student_name']?.toString() ??
                                  'Patient',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${appointment['matric_no'] ?? 'No matric number'} • ${scheduledAt == null ? 'Unknown schedule' : DateFormat('EEE, MMM d • hh:mm a').format(scheduledAt)}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          appointment['status']?.toString() ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        color: Colors.white,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Assessment',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appointment['assessment_subject']?.toString() ??
                              'Patient triage information',
                          style: const TextStyle(
                            color: RehabColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (triage.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Text(
                              'No AI assessment is linked to this appointment.',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 11,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              detailTile(
                                Icons.personal_injury_outlined,
                                'Injury area',
                                triage['pain_area'],
                              ),
                              detailTile(
                                Icons.my_location_rounded,
                                'Exact pain point',
                                triage['pain_point'],
                              ),
                              detailTile(
                                Icons.monitor_heart_outlined,
                                'Severity',
                                triage['severity'],
                              ),
                              detailTile(
                                Icons.schedule_outlined,
                                'Duration',
                                triage['duration'],
                              ),
                              detailTile(
                                Icons.medical_information_outlined,
                                'Discipline',
                                appointment['assessment_discipline'],
                              ),
                            ],
                          ),
                        const SizedBox(height: 22),
                        _clinicalTextSection(
                          'Physiotherapist Assessment',
                          appointment['evaluation'],
                        ),
                        const SizedBox(height: 12),
                        _clinicalTextSection(
                          'Prescription',
                          appointment['prescription'],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                      if (isScheduled && isToday) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showRecordSessionDialog(appointment);
                          },
                          icon: const Icon(Icons.edit_document, size: 17),
                          label: const Text('Record session'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _clinicalTextSection(String title, dynamic rawValue) {
    final value = rawValue?.toString().trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: RehabColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            value == null || value.isEmpty ? 'Not recorded yet.' : value,
            style: const TextStyle(
              color: RehabColors.muted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentClinicalChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Appointments",
                style: GoogleFonts.readexPro(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showApplyLeaveDialog,
                icon: const Icon(Icons.event_busy, size: 18),
                label: const Text("Set Unavailable Dates"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade900,
                  elevation: 0,
                  side: BorderSide(color: Colors.red.shade200),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchTerm = value),
            decoration: InputDecoration(
              labelText: 'Search appointment',
              hintText: 'Student name or matric number',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchTerm.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchTerm = '');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_visibleAppointments.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _searchTerm.isEmpty
                      ? "No appointments scheduled."
                      : "No matching appointments found.",
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _visibleAppointments.length,
                itemBuilder: (context, index) {
                  final a = _visibleAppointments[index];
                  final parsedDate = DateTime.tryParse(
                    a['schedule_time'] ?? '',
                  );
                  final date = parsedDate == null
                      ? 'Unknown'
                      : DateFormat(
                          'EEE, MMM d • hh:mm a',
                        ).format(parsedDate.toLocal());
                  final isScheduled = a['status'] == 'Scheduled';
                  final triage = a['triage_data'] is Map
                      ? Map<String, dynamic>.from(a['triage_data'] as Map)
                      : <String, dynamic>{};
                  final injuryArea =
                      triage['pain_area']?.toString().trim() ?? '';
                  final severity = triage['severity']?.toString().trim() ?? '';

                  final isToday =
                      parsedDate != null &&
                      parsedDate.toLocal().year == DateTime.now().year &&
                      parsedDate.toLocal().month == DateTime.now().month &&
                      parsedDate.toLocal().day == DateTime.now().day;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: RehabColors.border),
                    ),
                    child: InkWell(
                      onTap: () =>
                          _showAppointmentDetails(Map<String, dynamic>.from(a)),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.blue.shade100,
                              child: const Icon(
                                Icons.person,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['student_name'] ?? 'Unknown',
                                    style: GoogleFonts.readexPro(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Student ID: ${a['student_id'] ?? '—'}  •  Matric No: ${a['matric_no'] ?? 'Not provided'}",
                                    style: GoogleFonts.readexPro(
                                      fontSize: 13,
                                      color: Colors.blueGrey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  if (injuryArea.isNotEmpty ||
                                      severity.isNotEmpty) ...[
                                    Wrap(
                                      spacing: 7,
                                      runSpacing: 6,
                                      children: [
                                        if (injuryArea.isNotEmpty)
                                          _appointmentClinicalChip(
                                            Icons.personal_injury_outlined,
                                            injuryArea,
                                            RehabColors.primary,
                                          ),
                                        if (severity.isNotEmpty)
                                          _appointmentClinicalChip(
                                            Icons.monitor_heart_outlined,
                                            'Severity $severity',
                                            RehabColors.amber,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 7),
                                  ],
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        date,
                                        style: GoogleFonts.readexPro(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Chip(
                                  label: Text(
                                    a['status'] ?? '',
                                    style: TextStyle(
                                      color: isScheduled
                                          ? Colors.blue.shade900
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: isScheduled
                                      ? Colors.blue.shade50
                                      : Colors.grey.shade200,
                                  side: BorderSide.none,
                                ),
                                if (isScheduled) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            TeleconferenceService.join(
                                              context: context,
                                              meetingRoom: a['meeting_room']
                                                  ?.toString(),
                                            ),
                                        icon: const Icon(
                                          Icons.video_call_outlined,
                                          size: 16,
                                        ),
                                        label: const Text("Video Call"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _showTransferDialog(a),
                                        icon: const Icon(
                                          Icons.swap_horiz,
                                          size: 16,
                                        ),
                                        label: const Text("Transfer"),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              Colors.orange.shade800,
                                          side: BorderSide(
                                            color: Colors.orange.shade200,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                        ),
                                      ),
                                      if (isToday) ...[
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _showRecordSessionDialog(a),
                                          icon: const Icon(
                                            Icons.edit_document,
                                            size: 16,
                                          ),
                                          label: const Text("Record Session"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.blue.shade800,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 4: RENTALS
// ---------------------------------------------------------------------------
class PhysioRentalsTab extends StatefulWidget {
  final int myUserId;
  const PhysioRentalsTab({super.key, required this.myUserId});

  @override
  State<PhysioRentalsTab> createState() => _PhysioRentalsTabState();
}

class _PhysioRentalsTabState extends State<PhysioRentalsTab> {
  List<dynamic> _rentals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRentals();
  }

  Future<void> _fetchRentals() async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(
        Uri.parse('$apiUrl/physio/rentals/${widget.myUserId}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _rentals = data['rentals'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching rentals: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRentalStatus(int rentalId, String action) async {
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.post(
        Uri.parse(
          '$apiUrl/physio/rentals/$rentalId/$action'
          '?physio_id=${widget.myUserId}',
        ),
      );
      if (res.statusCode == 200) {
        _fetchRentals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rental $action successful!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorMsg =
            jsonDecode(res.body)['detail'] ?? 'Failed to $action rental';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("Error updating rental: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_rentals.isEmpty)
      return const Center(child: Text("No equipment rentals found."));

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _rentals.length,
      itemBuilder: (context, index) {
        final r = _rentals[index];
        String date = 'Unknown';
        final parsedDate = DateTime.tryParse(
          r['collection_date'] ?? '',
        )?.toLocal();
        if (parsedDate != null) {
          final timeStr = TimeOfDay.fromDateTime(parsedDate).format(context);
          date =
              '${parsedDate.day}/${parsedDate.month}/${parsedDate.year} $timeStr';
        }
        final isPending = r['status'] == 'Pending';
        final isApproved = r['status'] == 'Approved';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal.shade100,
                  child: const Icon(Icons.fitness_center, color: Colors.teal),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${r['student_name']} - ${r['equipment_name']}",
                        style: GoogleFonts.readexPro(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Student ID: ${r['student_id'] ?? '—'}  •  Matric No: ${r['matric_no'] ?? 'Not provided'}",
                        style: GoogleFonts.readexPro(
                          fontSize: 13,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            r['collection_method'] == 'Delivery'
                                ? Icons.local_shipping
                                : Icons.store,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${r['collection_method'] ?? 'Self-Pickup'}: $date",
                            style: GoogleFonts.readexPro(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      if (r['collection_method'] == 'Delivery' &&
                          r['delivery_address'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "${r['delivery_address']}",
                                style: GoogleFonts.readexPro(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (r['reason'] != null &&
                          r['reason'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Reason: ${r['reason']}",
                                style: GoogleFonts.readexPro(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (r['return_status'] != null &&
                          r['return_status'] != 'N/A') ...[
                        const SizedBox(height: 4),
                        Text(
                          "Return: ${r['return_status']}",
                          style: GoogleFonts.readexPro(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(
                      label: Text(
                        r['status'] ?? '',
                        style: TextStyle(
                          color: isPending
                              ? Colors.orange.shade900
                              : (isApproved
                                    ? Colors.green.shade900
                                    : Colors.red.shade900),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: isPending
                          ? Colors.orange.shade50
                          : (isApproved
                                ? Colors.green.shade50
                                : Colors.red.shade50),
                      side: BorderSide.none,
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _updateRentalStatus(
                              r['rental_record_id'],
                              'approve',
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text("Approve"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                              side: BorderSide(color: Colors.green.shade200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _updateRentalStatus(
                              r['rental_record_id'],
                              'reject',
                            ),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text("Reject"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
