import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rehab_ai/services/teleconference_service.dart';
import 'dart:async';
import 'package:rehab_ai/theme/rehab_theme.dart';
import 'package:rehab_ai/screens/student/appointments/my_appointments_page.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? teleconferenceRoom;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.teleconferenceRoom,
  });
}

class LiveChatPage extends StatefulWidget {
  final String? initialMessage;
  const LiveChatPage({super.key, this.initialMessage});

  @override
  State<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends State<LiveChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          "Hello! I'm your Rehab AI assistant. How can I help you with your therapy today?",
      isUser: false,
    ),
  ];
  bool _isTyping = false;
  bool _isChatEnded = false;
  RealtimeChannel? _sessionSubscription;

  int? _sessionId;
  int? _myUserId;
  final Set<String> _handledInvites = {};
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Fetch active session if any, or wait until first message to create one.
    _fetchActiveSession();
  }

  Future<void> _fetchActiveSession() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Find the user_id from the FastAPI using supabase_id to bypass RLS
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final userRes = await http.get(
        Uri.parse('$apiUrl/users/profile/${user.id}'),
      );
      if (userRes.statusCode != 200) return;
      final userData = jsonDecode(userRes.body);
      if (userData['exists'] != true) return;

      final userId = userData['user_id'];

      // Check if there is an active session
      final sessionRes = await _supabase
          .from('Live_Chat_Session')
          .select('session_id')
          .eq('student_id', userId)
          .eq('session_status', 'Active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (sessionRes != null) {
        setState(() {
          _sessionId = sessionRes['session_id'];
          // Clear initial welcome message as we will load history
          _messages.clear();
        });
        _subscribeToMessages();
      }
    } catch (e) {
      debugPrint("Error fetching active session: $e");
    } finally {
      if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
        _messageController.text = widget.initialMessage!;
        _sendMessage();
      }
    }
  }

  RealtimeChannel? _subscription;

  Future<void> _subscribeToMessages() async {
    if (_sessionId == null) return;

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
        _myUserId = userData['user_id'];
      }
    }

    if (_subscription != null) {
      await _supabase.removeChannel(_subscription!);
    }
    if (_sessionSubscription != null) {
      await _supabase.removeChannel(_sessionSubscription!);
    }

    // 1. Fetch initial data via REST
    try {
      final res = await _supabase
          .from('Chat_Log')
          .select()
          .eq('session_id', _sessionId!)
          .order('timestamp', ascending: true);
      if (res.isNotEmpty) {
        final lastMsg = List<dynamic>.from(res).last;
        if (lastMsg['timestamp'] != null) {
          _updateLastReadTimestamp(lastMsg['timestamp'].toString());
        }
      }
      if (mounted) {
        String? pendingInvite;
        setState(() {
          _messages.clear();
          for (var row in List<dynamic>.from(res)) {
            final textContent = row['content'] ?? '';
            if (textContent == '[SYSTEM: CHAT_CLOSED]') {
              _isChatEnded = true;
              continue;
            }
            final message = _chatMessageFromRow(row);
            _messages.add(message);
            if (message.teleconferenceRoom != null && !message.isUser) {
              pendingInvite = message.teleconferenceRoom;
            } else if (message.isUser &&
                (message.text == 'Video consultation accepted.' ||
                    message.text == 'Video consultation declined.')) {
              pendingInvite = null;
            }
          }
        });
        _scrollToBottom();
        if (pendingInvite != null) {
          unawaited(_showTeleconferenceInvite(pendingInvite!));
        }
      }
    } catch (e) {
      debugPrint("Error fetching messages: $e");
    }

    // 2. Subscribe to realtime updates
    _subscription = _supabase
        .channel('public:Chat_Log:session_$_sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Chat_Log',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: _sessionId!,
          ),
          callback: (payload) {
            final newMsg = payload.newRecord;
            if (newMsg['timestamp'] != null) {
              _updateLastReadTimestamp(newMsg['timestamp'].toString());
            }
            final textContent = newMsg['content'] ?? '';
            if (mounted) {
              setState(() {
                if (textContent == '[SYSTEM: CHAT_CLOSED]') {
                  _isChatEnded = true;
                  return;
                }
                // Prevent duplicating the user's own message that was added optimistically
                if (newMsg['sender_id'] == _myUserId) {
                  if (_messages.isNotEmpty &&
                      _messages.last.isUser &&
                      _messages.last.text == textContent) {
                    return;
                  }
                }
                _messages.add(_chatMessageFromRow(newMsg));
              });
              _scrollToBottom();
              final room = TeleconferenceService.roomFromInvite(textContent);
              if (room != null && newMsg['sender_id'] != _myUserId) {
                unawaited(_showTeleconferenceInvite(room));
              }
            }
          },
        )
        .subscribe();

    // 3. Subscribe to session status updates
    _sessionSubscription = _supabase
        .channel('public:Live_Chat_Session:session_$_sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'Live_Chat_Session',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: _sessionId!,
          ),
          callback: (payload) {
            if (mounted) {
              final updatedRecord = payload.newRecord;
              if (updatedRecord['session_status'] == 'Ended') {
                setState(() {
                  _isChatEnded = true;
                });
              }
            }
          },
        )
        .subscribe();
  }

  ChatMessage _chatMessageFromRow(Map<String, dynamic> row) {
    final content = row['content']?.toString() ?? '';
    final room = TeleconferenceService.roomFromInvite(content);
    return ChatMessage(
      text: room == null
          ? content
          : 'Your physiotherapist is inviting you to a video consultation.',
      isUser: row['sender_id'] == _myUserId,
      teleconferenceRoom: room,
    );
  }

  Future<void> _showTeleconferenceInvite(String room) async {
    if (!mounted || _handledInvites.contains(room)) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('teleconference_handled_$room') == true || !mounted) {
      return;
    }

    _handledInvites.add(room);
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.video_call_outlined,
          size: 44,
          color: Color(0xFF1565C0),
        ),
        title: const Text('Video consultation invitation'),
        content: const Text(
          'Your physiotherapist would like to start a video consultation now.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Decline'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.video_call),
            label: const Text('Accept & Join'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
    if (accepted == null) return;

    final responded = await _respondToTeleconference(accepted: accepted);
    if (!responded) {
      _handledInvites.remove(room);
      return;
    }
    await prefs.setBool('teleconference_handled_$room', true);
    if (accepted && mounted) {
      await TeleconferenceService.join(context: context, meetingRoom: room);
    }
  }

  Future<void> _joinOrRespondToInvite(String room) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('teleconference_handled_$room') == true) {
      if (mounted) {
        await TeleconferenceService.join(context: context, meetingRoom: room);
      }
      return;
    }
    _handledInvites.remove(room);
    await _showTeleconferenceInvite(room);
  }

  Future<bool> _respondToTeleconference({required bool accepted}) async {
    if (_sessionId == null || _myUserId == null) return false;
    final apiUrl = kIsWeb
        ? 'http://127.0.0.1:8000'
        : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/chats/$_sessionId/teleconference/respond'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _myUserId, 'accepted': accepted}),
      );
      if (response.statusCode != 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to respond to the invitation.')),
        );
      }
      return response.statusCode == 200;
    } catch (error) {
      debugPrint('Unable to respond to teleconference invitation: $error');
      return false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Not logged in")));
      return;
    }

    _messageController.clear();

    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final userRes = await http.get(
        Uri.parse('$apiUrl/users/profile/${user.id}'),
      );
      if (userRes.statusCode != 200) return;
      final userData = jsonDecode(userRes.body);
      if (userData['exists'] != true) return;

      final userId = userData['user_id'];

      if (_sessionId == null) {
        // Start a new session via FastAPI triage
        setState(() {
          _messages.add(ChatMessage(text: text, isUser: true));
          _isTyping = true;
        });
        _scrollToBottom();

        final apiUrl = kIsWeb
            ? 'http://127.0.0.1:8000'
            : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
        final response = await http.post(
          Uri.parse('$apiUrl/chat/start'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"user_id": userId, "message": text}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _sessionId = data['session_id'];
            _isTyping = false;
          });
          _subscribeToMessages();
        } else {
          setState(() {
            _isTyping = false;
            _messages.add(
              ChatMessage(text: "Failed to start chat session.", isUser: false),
            );
          });
        }
      } else {
        // Active session exists, send message via FastAPI to bypass RLS
        setState(() {
          _messages.add(ChatMessage(text: text, isUser: true));
          _isTyping = true;
        });
        _scrollToBottom();

        final apiUrl = kIsWeb
            ? 'http://127.0.0.1:8000'
            : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
        final response = await http.post(
          Uri.parse('$apiUrl/chat/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "session_id": _sessionId,
            "user_id": userId,
            "message": text,
          }),
        );

        if (response.statusCode != 200) {
          setState(() {
            _isTyping = false;
            _messages.add(
              ChatMessage(text: "Failed to send message.", isUser: false),
            );
          });
        } else {
          setState(() {
            _isTyping = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    }
  }

  Future<void> _updateLastReadTimestamp(String timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_read_chat_timestamp', timestamp);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
  void dispose() {
    _subscription?.unsubscribe();
    _sessionSubscription?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.rehabBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.rehabSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.rehabBorder),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    'Live Chat',
                    style: GoogleFonts.readexPro(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert, color: Color(0xFF1565C0)),
                  ),
                ],
              ),
            ),

            // Main Chat Area
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                decoration: BoxDecoration(
                  color: context.rehabSurface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Chat Messages List
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(20.0),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return _buildTypingIndicator();
                          }
                          final message = _messages[index];
                          return _buildChatBubble(message);
                        },
                      ),
                    ),

                    // Bottom Input Area
                    if (_isChatEnded)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          "This chat session has ended.",
                          style: GoogleFonts.readexPro(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Quick Replies (Optional)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildQuickReply('Need assistance'),
                                   const SizedBox(width: 8),
                                   _buildQuickReply('Book Appointment'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Input Field
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.rehabInput,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: context.rehabBorder),
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
                                      style: GoogleFonts.readexPro(
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Type your message...',
                                        hintStyle: GoogleFonts.readexPro(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _sendMessage,
                                    icon: const Icon(
                                      Icons.send_rounded,
                                      color: Color(0xFF1565C0),
                                      size: 24,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    if (message.teleconferenceRoom != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: context.isDarkMode
              ? RehabColors.darkSurfaceElevated
              : const Color(0xFFE8F5F1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: GoogleFonts.readexPro(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _joinOrRespondToInvite(message.teleconferenceRoom!),
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('Join video consultation'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF1565C0) : context.rehabInput,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: message.isUser
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: message.isUser
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.readexPro(
            fontSize: 14,
            height: 1.4,
            color: message.isUser
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.rehabInput,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Typing...',
              style: GoogleFonts.readexPro(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReply(String text) {
    return InkWell(
      onTap: () {
        if (text == 'Book Appointment') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MyAppointmentsPage(
                openBookingOnStart: true,
                closeAfterBooking: true,
              ),
            ),
          );
        } else {
          _messageController.text = text;
          _sendMessage();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: context.rehabSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: GoogleFonts.readexPro(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1565C0),
          ),
        ),
      ),
    );
  }
}
