import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rehab_ai/screens/login_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PhysioDashboard extends StatefulWidget {
  const PhysioDashboard({super.key});

  @override
  State<PhysioDashboard> createState() => _PhysioDashboardState();
}

class _PhysioDashboardState extends State<PhysioDashboard> {
  final _supabase = Supabase.instance.client;
  int? _myUserId;
  int _selectedIndex = 0;
  
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
      }
    }
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
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: Text('Live Chat'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.trending_up),
                selectedIcon: Icon(Icons.trending_up, size: 28),
                label: Text('Progress'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: Text('Appointments'),
              ),
              NavigationRailDestination(
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
        return PhysioLiveChatTab(myUserId: _myUserId!);
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
  const PhysioLiveChatTab({super.key, required this.myUserId});

  @override
  State<PhysioLiveChatTab> createState() => _PhysioLiveChatTabState();
}

class _PhysioLiveChatTabState extends State<PhysioLiveChatTab> {
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
        });
      }
    } catch (e) {
      debugPrint("Error fetching chats: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    : ListView.builder(
                        itemCount: _chats.length,
                        itemBuilder: (context, index) {
                          final chat = _chats[index];
                          final isSelected = _selectedChat?['session_id'] == chat['session_id'];
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: Colors.blue[50],
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: const Icon(Icons.person, color: Colors.blue),
                            ),
                            title: Text(chat['student_name'] ?? 'Unknown Patient', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${chat['discipline']} • ${chat['session_status']}"),
                            onTap: () => setState(() => _selectedChat = chat),
                          );
                        },
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
                ),
        ),
      ],
    );
  }
}

// (The Chat Interface widget from before)
class PhysioChatInterface extends StatefulWidget {
  final int sessionId;
  final int myUserId;
  final dynamic triageData;

  const PhysioChatInterface({super.key, required this.sessionId, required this.myUserId, required this.triageData});

  @override
  State<PhysioChatInterface> createState() => _PhysioChatInterfaceState();
}

class _PhysioChatInterfaceState extends State<PhysioChatInterface> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  List<dynamic> _messages = [];
  RealtimeChannel? _subscription;
  bool _isLoading = true;

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
    } catch (e) {
      debugPrint("Error loading messages: $e");
    } finally {
      setState(() => _isLoading = false);
    }

    _subscription = _supabase.channel('public:Chat_Log:session_${widget.sessionId}')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'Chat_Log', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'session_id', value: widget.sessionId),
          callback: (payload) {
            setState(() => _messages.add(payload.newRecord));
          },
        ).subscribe();
  }

  Future<void> _sendMessage() async {
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
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    if (_subscription != null) _supabase.removeChannel(_subscription!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_appointments.isEmpty) return const Center(child: Text("No appointments scheduled."));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
        columns: const [
          DataColumn(label: Text('Patient')),
          DataColumn(label: Text('Schedule Time')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Evaluation')),
        ],
        rows: _appointments.map((a) {
          final date = DateTime.tryParse(a['schedule_time'] ?? '')?.toLocal().toString().split('.')[0] ?? 'Unknown';
          return DataRow(cells: [
            DataCell(Text(a['student_name'] ?? 'Unknown')),
            DataCell(Text(date)),
            DataCell(Chip(label: Text(a['status'] ?? ''))),
            DataCell(Text(a['evaluation'] ?? 'N/A')),
          ]);
        }).toList(),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_rentals.isEmpty) return const Center(child: Text("No equipment rentals found."));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
        columns: const [
          DataColumn(label: Text('Patient')),
          DataColumn(label: Text('Equipment')),
          DataColumn(label: Text('Collection Date')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Return Status')),
        ],
        rows: _rentals.map((r) {
          final date = DateTime.tryParse(r['collection_date'] ?? '')?.toLocal().toString().split(' ')[0] ?? 'Unknown';
          return DataRow(cells: [
            DataCell(Text(r['student_name'] ?? 'Unknown')),
            DataCell(Text(r['equipment_name'] ?? 'Unknown')),
            DataCell(Text(date)),
            DataCell(Chip(label: Text(r['status'] ?? ''), backgroundColor: r['status'] == 'Pending' ? Colors.orange[100] : Colors.green[100])),
            DataCell(Text(r['return_status'] ?? 'N/A')),
          ]);
        }).toList(),
      ),
    );
  }
}
