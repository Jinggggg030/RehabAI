import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rehab_ai/screens/login_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
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
  
  @override
  void initState() {
    super.initState();
    _initDashboard();
  }
  
  Future<void> _initDashboard() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    final userRes = await http.get(Uri.parse('$apiUrl/users/profile/${user.id}'));
    
    if (userRes.statusCode == 200) {
      final userData = jsonDecode(userRes.body);
      if (userData['exists'] == true) {
        setState(() {
          _myUserId = userData['user_id'];
        });
        _fetchAssignedSessions();
        _setupGlobalNotifications();
      }
    }
  }

  Future<void> _fetchAssignedSessions() async {
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/physio/chats/$_myUserId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _assignedSessionIds = (data['chats'] as List).map((c) => c['session_id'] as int).toList();
        });
      }
    } catch(e) {}
  }

  void _setupGlobalNotifications() {
    _globalNotificationSub = _supabase.channel('public:Chat_Log:notifications_global')
      .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'Chat_Log',
        callback: (payload) {
          final newRecord = payload.newRecord;
          if (newRecord['sender_id'] != _myUserId) {
            final sessionId = newRecord['session_id'] as int;
            if (_assignedSessionIds.contains(sessionId)) {
              setState(() {
                _unreadChats.add(sessionId.toString());
              });
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
        }
      ).subscribe();
  }

  @override
  void dispose() {
    if (_globalNotificationSub != null) _supabase.removeChannel(_globalNotificationSub!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Physiotherapist Portal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            selectedIconTheme: IconThemeData(color: Colors.blue[800]),
            selectedLabelTextStyle: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
            destinations: [
              NavigationRailDestination(
                icon: Badge(
                  isLabelVisible: _unreadChats.isNotEmpty,
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _unreadChats.isNotEmpty,
                  child: const Icon(Icons.chat_bubble),
                ),
                label: const Text('Live Chat'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.trending_up),
                selectedIcon: Icon(Icons.trending_up, size: 28),
                label: Text('Progress'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: Text('Appointments'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.medical_services_outlined),
                selectedIcon: Icon(Icons.medical_services),
                label: Text('Rentals'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.black12),
          // Main Content Area
          Expanded(
            child: _buildMainContent(),
          ),
        ],
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
          myUserId: _myUserId!, 
          unreadChats: _unreadChats, 
          onChatRead: (sessionId) {
            setState(() {
              _unreadChats.remove(sessionId);
            });
          }
        );
      case 1:
        return PhysioPatientsTab(myUserId: _myUserId!);
      case 2:
        return PhysioAppointmentsTab(myUserId: _myUserId!);
      case 3:
        return PhysioRentalsTab(myUserId: _myUserId!);
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

  const PhysioLiveChatTab({super.key, required this.myUserId, required this.unreadChats, required this.onChatRead});

  @override
  State<PhysioLiveChatTab> createState() => _PhysioLiveChatTabState();
}

class _PhysioLiveChatTabState extends State<PhysioLiveChatTab> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _chats = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedChat;

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  Future<void> _fetchChats() async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/physio/chats/${widget.myUserId}'));
      if (res.statusCode == 200) {
        
        final data = jsonDecode(res.body);
        setState(() {
          _chats = data['chats'] ?? [];
          // Update selected chat if it was modified
          if (_selectedChat != null) {
            final updated = _chats.where((c) => c['session_id'] == _selectedChat!['session_id']).toList();
            if (updated.isNotEmpty) _selectedChat = updated.first;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching chats: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeChats = _chats.where((c) => c['session_status'] != 'Closed').toList();
    final pastChats = _chats.where((c) => c['session_status'] == 'Closed').toList();

    return Row(
      children: [
        // Left Sidebar: Chat List
        Container(
          width: 320,
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
                    const Text("Assigned Chats", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchChats),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _chats.isEmpty
                    ? const Center(child: Text("No patients assigned yet.", style: TextStyle(color: Colors.grey)))
                    : ListView(
                        children: [
                          if (activeChats.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("ACTIVE CHATS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                          ...activeChats.map((chat) {
                            final isSelected = _selectedChat?['session_id'] == chat['session_id'];
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.blue[50],
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: const Icon(Icons.person, color: Colors.blue),
                              ),
                              title: Text(chat['student_name'] ?? 'Unknown Patient', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("${chat['discipline']}"),
                              trailing: widget.unreadChats.contains(chat['session_id'].toString())
                                  ? Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedChat = chat;
                                });
                                widget.onChatRead(chat['session_id'].toString());
                              },
                            );
                          }),
                          if (pastChats.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(8, 16, 8, 8),
                              child: Text("PAST CONVERSATIONS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                          ...pastChats.map((chat) {
                            final isSelected = _selectedChat?['session_id'] == chat['session_id'];
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.grey[200],
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[300],
                                child: const Icon(Icons.person, color: Colors.grey),
                              ),
                              title: Text(chat['student_name'] ?? 'Unknown Patient', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              subtitle: const Text("Closed", style: TextStyle(color: Colors.grey)),
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
                      Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("Select a patient to start messaging", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : PhysioChatInterface(
                  sessionId: _selectedChat!['session_id'],
                  myUserId: widget.myUserId,
                  triageData: _selectedChat!['triage_data'],
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
  final dynamic triageData;
  final bool isClosed;
  final VoidCallback onChatClosed;

  const PhysioChatInterface({super.key, required this.sessionId, required this.myUserId, required this.triageData, required this.isClosed, required this.onChatClosed});

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
      final res = await _supabase.from('Chat_Log').select().eq('session_id', widget.sessionId).order('timestamp', ascending: true);
      setState(() => _messages = List<dynamic>.from(res));
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error loading messages: $e");
    } finally {
      setState(() => _isLoading = false);
    }

    _subscription = _supabase.channel('public:Chat_Log:session_${widget.sessionId}')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'Chat_Log', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'session_id', value: widget.sessionId),
          callback: (payload) {
            setState(() => _messages.add(payload.newRecord));
            _scrollToBottom();
          },
        ).subscribe();
  }

  Future<void> _sendMessage() async {
    if (widget.isClosed) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    try {
      
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      await http.post(
        Uri.parse('$apiUrl/chat/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"session_id": widget.sessionId, "user_id": widget.myUserId, "message": text}),
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
        content: const Text("Are you sure you want to close this chat? You will not be able to send any more messages."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("End Chat")),
        ],
      )
    );

    if (confirm != true) return;

    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.put(Uri.parse('$apiUrl/physio/chats/${widget.sessionId}/close'));
      if (res.statusCode == 200) {
        widget.onChatClosed(); // Refresh the list
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to end chat")));
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
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.black12))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Conversation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (!widget.isClosed)
                OutlinedButton.icon(
                  onPressed: _endChat,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text("End Chat"),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                )
              else
                Chip(label: const Text("Closed", style: TextStyle(color: Colors.white)), backgroundColor: Colors.grey[600]),
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
                const Text("AI Triage Summary", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                const SizedBox(height: 4),
                Text("Area: ${widget.triageData['pain_area'] ?? 'Unknown'} | Severity: ${widget.triageData['severity'] ?? 'Unknown'} | Duration: ${widget.triageData['duration'] ?? 'Unknown'}", style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),
        Expanded(
          child: _isLoading ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = msg['sender_id'] == widget.myUserId;
                  final isSystem = msg['sender_id'] == null;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : (isSystem ? Alignment.center : Alignment.centerLeft),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: isMe ? Colors.blue[600] : (isSystem ? Colors.grey[300] : Colors.white), borderRadius: BorderRadius.circular(12)),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
                      child: Text(msg['content'] ?? '', style: TextStyle(color: isMe ? Colors.white : (isSystem ? Colors.black54 : Colors.black87), fontStyle: isSystem ? FontStyle.italic : FontStyle.normal)),
                    ),
                  );
                },
              ),
        ),
        if (!widget.isClosed)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(hintText: "Type a message...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(onPressed: _sendMessage, backgroundColor: Colors.blue[800], elevation: 0, child: const Icon(Icons.send, color: Colors.white)),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            width: double.infinity,
            alignment: Alignment.center,
            child: const Text("This conversation has ended.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
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
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/physio/patients/${widget.myUserId}'));
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
    if (_patients.isEmpty) return const Center(child: Text("No patients assigned."));

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final p = _patients[index];
        final exercises = p['exercises'] as List<dynamic>? ?? [];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.green[100], child: const Icon(Icons.person, color: Colors.green)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['student_name'] ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(p['email'] ?? '', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (p['active_prescription'] != null) ...[
                  Text("Diagnosis: ${p['active_prescription']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (exercises.isEmpty) const Text("No exercises assigned yet.", style: TextStyle(color: Colors.grey)),
                  ...exercises.map((ex) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.fitness_center, color: Colors.black54),
                    title: Text(ex['name']),
                    subtitle: Text("Sets: ${ex['assigned_sets']} | Eval: ${ex['evaluation'] ?? 'None'}"),
                  )),
                ] else ...[
                  const Text("No active prescription.", style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic)),
                ]
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

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/physio/appointments/${widget.myUserId}'));
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

  Future<void> _showTransferDialog(dynamic appointment) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      }
    );

    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/physiotherapists/colleagues/${widget.myUserId}'));
      
      if (!mounted) return;
      Navigator.pop(context); // Pop loading dialog

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final colleagues = data['colleagues'] as List<dynamic>? ?? [];
        
        if (colleagues.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No colleagues with the same specialization found.")));
          }
          return;
        }

        int? selectedColleagueId = colleagues.first['therapist_id'];

        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return StatefulBuilder(builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text("Transfer Appointment"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Select a colleague to transfer this appointment to:"),
                      const SizedBox(height: 16),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: selectedColleagueId,
                        items: colleagues.map<DropdownMenuItem<int>>((c) {
                          return DropdownMenuItem<int>(
                            value: c['therapist_id'],
                            child: Text("${c['name']} (${c['specialization']})"),
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
                            Uri.parse('$apiUrl/appointments/${appointment['appointment_id']}/transfer'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({"new_therapist_id": selectedColleagueId}),
                          );
                          if (transRes.statusCode == 200) {
                            if (mounted) Navigator.pop(dialogContext);
                            _fetchAppointments();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appointment transferred successfully!")));
                            }
                          }
                        } catch (e) {
                          debugPrint("Transfer error: $e");
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                      child: const Text("Confirm Transfer"),
                    ),
                  ],
                );
              });
            }
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
      builder: (context) => const Center(child: CircularProgressIndicator())
    );

    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/physiotherapists/colleagues/${widget.myUserId}'));
      
      if (!mounted) return;
      Navigator.pop(context); // Pop loading

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final colleagues = data['colleagues'] as List<dynamic>? ?? [];
        
        if (colleagues.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No colleagues available to cover.")));
          }
          return;
        }

        int? selectedColleagueId = colleagues.first['therapist_id'];

        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return StatefulBuilder(builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text("Apply Emergency Leave"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Leave Period: ${picked.start.toLocal().toString().split(' ')[0]} to ${picked.end.toLocal().toString().split(' ')[0]}"),
                      const SizedBox(height: 16),
                      const Text("Select a covering colleague:"),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: selectedColleagueId,
                        items: colleagues.map<DropdownMenuItem<int>>((c) {
                          return DropdownMenuItem<int>(
                            value: c['therapist_id'],
                            child: Text("${c['name']} (${c['specialization']})"),
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
                            Uri.parse('$apiUrl/physio/leave/${widget.myUserId}'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                                "start_date": picked.start.toUtc().toIso8601String(),
                                "end_date": picked.end.toUtc().toIso8601String(),
                                "cover_colleague_id": selectedColleagueId
                            }),
                          );
                          if (leaveRes.statusCode == 200) {
                            if (mounted) Navigator.pop(dialogContext);
                            _fetchAppointments();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leave applied & appointments transferred!")));
                            }
                          }
                        } catch (e) {
                          debugPrint("Leave error: $e");
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
                      child: const Text("Confirm Leave"),
                    ),
                  ],
                );
              });
            }
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error: $e");
    }
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
              Text("Appointments", style: GoogleFonts.readexPro(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
              ElevatedButton.icon(
                onPressed: _showApplyLeaveDialog,
                icon: const Icon(Icons.time_to_leave, size: 18),
                label: const Text("Apply Leave"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade900, elevation: 0, side: BorderSide(color: Colors.red.shade200)),
              )
            ],
          ),
          const SizedBox(height: 24),
          if (_appointments.isEmpty)
             const Expanded(child: Center(child: Text("No appointments scheduled.")))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _appointments.length,
                itemBuilder: (context, index) {
                  final a = _appointments[index];
                  final date = DateTime.tryParse(a['schedule_time'] ?? '')?.toLocal().toString().split('.')[0] ?? 'Unknown';
                  final isScheduled = a['status'] == 'Scheduled';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.person, color: Colors.blue),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['student_name'] ?? 'Unknown', style: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(date, style: GoogleFonts.readexPro(fontSize: 14, color: Colors.grey.shade700)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Chip(
                                label: Text(a['status'] ?? '', style: TextStyle(color: isScheduled ? Colors.blue.shade900 : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                                backgroundColor: isScheduled ? Colors.blue.shade50 : Colors.grey.shade200,
                                side: BorderSide.none,
                              ),
                              if (isScheduled) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _showTransferDialog(a),
                                  icon: const Icon(Icons.swap_horiz, size: 16),
                                  label: const Text("Transfer"),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800, side: BorderSide(color: Colors.orange.shade200)),
                                )
                              ]
                            ],
                          )
                        ],
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
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/physio/rentals/${widget.myUserId}'));
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
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.post(Uri.parse('$apiUrl/physio/rentals/$rentalId/$action'));
      if (res.statusCode == 200) {
        _fetchRentals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rental $action successful!'), backgroundColor: Colors.green),
          );
        }
      } else {
        final errorMsg = jsonDecode(res.body)['detail'] ?? 'Failed to $action rental';
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
    if (_rentals.isEmpty) return const Center(child: Text("No equipment rentals found."));

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _rentals.length,
      itemBuilder: (context, index) {
        final r = _rentals[index];
        final date = DateTime.tryParse(r['collection_date'] ?? '')?.toLocal().toString().split(' ')[0] ?? 'Unknown';
        final isPending = r['status'] == 'Pending';
        final isApproved = r['status'] == 'Approved';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      Text("${r['student_name']} - ${r['equipment_name']}", style: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text("Collection: $date", style: GoogleFonts.readexPro(fontSize: 14, color: Colors.grey.shade700)),
                        ],
                      ),
                      if (r['return_status'] != null && r['return_status'] != 'N/A') ...[
                        const SizedBox(height: 4),
                        Text("Return: ${r['return_status']}", style: GoogleFonts.readexPro(fontSize: 12, color: Colors.grey.shade600)),
                      ]
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(
                      label: Text(r['status'] ?? '', style: TextStyle(color: isPending ? Colors.orange.shade900 : (isApproved ? Colors.green.shade900 : Colors.red.shade900), fontWeight: FontWeight.bold)),
                      backgroundColor: isPending ? Colors.orange.shade50 : (isApproved ? Colors.green.shade50 : Colors.red.shade50),
                      side: BorderSide.none,
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _updateRentalStatus(r['rental_record_id'], 'approve'),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text("Approve"),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade700, side: BorderSide(color: Colors.green.shade200), padding: const EdgeInsets.symmetric(horizontal: 8)),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _updateRentalStatus(r['rental_record_id'], 'reject'),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text("Reject"),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700, side: BorderSide(color: Colors.red.shade200), padding: const EdgeInsets.symmetric(horizontal: 8)),
                          ),
                        ],
                      )
                    ]
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
