import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/utils/global_state.dart';
import 'package:rehab_ai/screens/live_chat_page.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: GlobalState.hasUnreadLiveChat,
      builder: (context, hasUnread, child) {
        return PopupMenuButton<String>(
          icon: Badge(
            isLabelVisible: hasUnread,
            child: const Icon(Icons.notifications_none, color: Color(0xFF207866)),
          ),
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (BuildContext context) {
            if (!hasUnread) {
              return [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'No new notifications',
                    style: GoogleFonts.readexPro(color: Colors.grey),
                  ),
                ),
              ];
            }
            return [
              PopupMenuItem<String>(
                value: 'chat',
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF207866),
                      radius: 16,
                      child: Icon(Icons.chat, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('New Message', style: GoogleFonts.readexPro(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('You have a new message from the physiotherapist.', style: GoogleFonts.readexPro(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
          onSelected: (value) {
            if (value == 'chat') {
              GlobalState.hasUnreadLiveChat.value = false;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LiveChatPage()),
              );
            }
          },
        );
      },
    );
  }
}
