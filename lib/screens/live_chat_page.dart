import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class LiveChatPage extends StatefulWidget {
  const LiveChatPage({super.key});

  @override
  State<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends State<LiveChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<ChatMessage> _messages = [
    ChatMessage(text: "Hello! I'm your Rehab AI assistant. How can I help you with your therapy today?", isUser: false),
  ];
  bool _isTyping = false;
  bool _isChatEnded = false;
  RealtimeChannel? _sessionSubscription;

  int? _sessionId;
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
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final userRes = await http.get(Uri.parse('$apiUrl/users/profile/${user.id}'));
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
    }
  }

  RealtimeChannel? _subscription;

  Future<void> _subscribeToMessages() async {
    if (_sessionId == null) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;
      
    final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    final userRes = await http.get(Uri.parse('$apiUrl/users/profile/${user.id}'));
    int? myUserId;
    if (userRes.statusCode == 200) {
      final userData = jsonDecode(userRes.body);
      if (userData['exists'] == true) {
        myUserId = userData['user_id'];
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
      final res = await _supabase.from('Chat_Log').select().eq('session_id', _sessionId!).order('timestamp', ascending: true);
      if (mounted) {
        setState(() {
          _messages.clear();
          for (var row in List<dynamic>.from(res)) {
            final textContent = row['content'] ?? '';
            if (textContent == '[SYSTEM: CHAT_CLOSED]') {
              _isChatEnded = true;
              continue;
            }
            _messages.add(ChatMessage(
              text: textContent,
              isUser: row['sender_id'] == myUserId,
            ));
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error fetching messages: $e");
    }

    // 2. Subscribe to realtime updates
    _subscription = _supabase.channel('public:Chat_Log:session_$_sessionId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'Chat_Log',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'session_id', value: _sessionId!),
        callback: (payload) {
          final newMsg = payload.newRecord;
          final textContent = newMsg['content'] ?? '';
          if (mounted) {
            setState(() {
              if (textContent == '[SYSTEM: CHAT_CLOSED]') {
                _isChatEnded = true;
                return;
              }
              // Prevent duplicating the user's own message that was added optimistically
              if (newMsg['sender_id'] == myUserId) {
                if (_messages.isNotEmpty && _messages.last.isUser && _messages.last.text == textContent) {
                  return;
                }
              }
              _messages.add(ChatMessage(
                text: textContent,
                isUser: newMsg['sender_id'] == myUserId,
              ));
            });
            _scrollToBottom();
          }
        }
      ).subscribe();

    // 3. Subscribe to session status updates
    _sessionSubscription = _supabase.channel('public:Live_Chat_Session:session_$_sessionId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'Live_Chat_Session',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'session_id', value: _sessionId!),
        callback: (payload) {
          if (mounted) {
            final updatedRecord = payload.newRecord;
            if (updatedRecord['session_status'] == 'Ended') {
              setState(() {
                _isChatEnded = true;
              });
            }
          }
        }
      ).subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not logged in")));
      return;
    }

    _messageController.clear();

    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final userRes = await http.get(Uri.parse('$apiUrl/users/profile/${user.id}'));
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

        final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
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
            _messages.add(ChatMessage(text: "Failed to start chat session.", isUser: false));
          });
        }
      } else {
        // Active session exists, send message via FastAPI to bypass RLS
        setState(() {
          _messages.add(ChatMessage(text: text, isUser: true));
          _isTyping = true;
        });
        _scrollToBottom();

        final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
        final response = await http.post(
          Uri.parse('$apiUrl/chat/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "session_id": _sessionId,
            "user_id": userId,
            "message": text
          }),
        );
        
        if (response.statusCode != 200) {
          setState(() {
            _isTyping = false;
            _messages.add(ChatMessage(text: "Failed to send message.", isUser: false));
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black54),
                    ),
                  ),
                  Text(
                    'Live Chat',
                    style: GoogleFonts.readexPro(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF207866),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert, color: Color(0xFF207866)),
                  ),
                ],
              ),
            ),

            // Main Chat Area
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                                _buildQuickReply('Check progress'),
                                const SizedBox(width: 8),
                                _buildQuickReply('Book session'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Input Field
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.attach_file, color: Colors.black54, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    style: GoogleFonts.readexPro(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Type your message...',
                                      hintStyle: GoogleFonts.readexPro(
                                        color: Colors.grey.shade400,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _sendMessage,
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    color: Color(0xFF207866),
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
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF207866) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: message.isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: message.isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.readexPro(
            fontSize: 14,
            height: 1.4,
            color: message.isUser ? Colors.white : Colors.black87,
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
        decoration: const BoxDecoration(
          color: Color(0xFFF0F2F5),
          borderRadius: BorderRadius.only(
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
        _messageController.text = text;
        _sendMessage();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF207866).withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: GoogleFonts.readexPro(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF207866),
          ),
        ),
      ),
    );
  }
}
