import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/utils/global_state.dart';
import 'package:rehab_ai/screens/live_chat_page.dart';
import 'package:rehab_ai/screens/rental_status_page.dart';
import 'package:rehab_ai/screens/my_appointments_page.dart';
import 'package:rehab_ai/screens/rehabilitation_exercises_page.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  IconData _getIconForType(String type) {
    switch (type) {
      case 'chat': return Icons.chat;
      case 'rental': return Icons.handyman;
      case 'appointment': return Icons.calendar_today;
      case 'exercise': return Icons.fitness_center;
      default: return Icons.notifications;
    }
  }

  void _handleTap(BuildContext context, String type) {
    switch (type) {
      case 'chat':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveChatPage()));
        break;
      case 'rental':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RentalStatusPage()));
        break;
      case 'appointment':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAppointmentsPage()));
        break;
      case 'exercise':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RehabilitationExercisesPage()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: GlobalState.notifications,
      builder: (context, notifications, child) {
        final hasUnread = notifications.isNotEmpty;
        
        return PopupMenuButton<dynamic>(
          icon: Badge(
            isLabelVisible: hasUnread,
            label: Text(notifications.length.toString()),
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
            return notifications.map((notif) {
              return PopupMenuItem<dynamic>(
                value: notif,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF207866),
                      radius: 16,
                      child: Icon(_getIconForType(notif['type']), color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(notif['title'], style: GoogleFonts.readexPro(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(notif['message'], style: GoogleFonts.readexPro(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          onSelected: (notif) {
            if (notif != null) {
              _handleTap(context, notif['type']);
            }
          },
        );
      },
    );
  }
}
