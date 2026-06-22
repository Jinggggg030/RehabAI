import 'package:flutter/material.dart';
import 'package:rehab_ai/screens/student/rentals/equipment_rental_page.dart';
import 'package:rehab_ai/screens/support/help_support_page.dart';
import 'package:rehab_ai/screens/student/chat/live_chat_page.dart';
import 'package:rehab_ai/screens/student/appointments/my_appointments_page.dart';
import 'package:rehab_ai/screens/student/exercises/rehabilitation_exercises_page.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';
import 'package:rehab_ai/widgets/notification_bell.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = <_ServiceItem>[
      _ServiceItem(
        title: 'Live Chat',
        description: 'Speak with RehabAI and your physiotherapist',
        icon: Icons.forum_rounded,
        colors: const [Color(0xFF1565C0), Color(0xFF1976D2)],
        destination: const LiveChatPage(),
      ),
      _ServiceItem(
        title: 'Rehabilitation',
        description: 'AI-guided exercises and recovery plans',
        icon: Icons.fitness_center_rounded,
        colors: const [Color(0xFF059669), Color(0xFF10B981)],
        destination: const RehabilitationExercisesPage(),
      ),
      _ServiceItem(
        title: 'Appointments',
        description: 'Book in-person or video consultations',
        icon: Icons.calendar_month_rounded,
        colors: const [Color(0xFF0891B2), Color(0xFF06B6D4)],
        destination: const MyAppointmentsPage(),
      ),
      _ServiceItem(
        title: 'Equipment Rental',
        description: 'Request rehabilitation equipment',
        icon: Icons.medical_services_rounded,
        colors: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
        destination: const EquipmentRentalPage(),
      ),
      _ServiceItem(
        title: 'Help & Support',
        description: 'Contact the RehabAI support team',
        icon: Icons.support_agent_rounded,
        colors: const [Color(0xFFF59E0B), Color(0xFFF97316)],
        destination: const HelpSupportPage(),
      ),
    ];

    return Scaffold(
      backgroundColor: context.rehabBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 190,
              padding: const EdgeInsets.fromLTRB(24, 54, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -35,
                    top: -55,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Care Hub',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Everything you need for a connected recovery.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.13),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const IconTheme(
                          data: IconThemeData(color: Colors.white),
                          child: NotificationBell(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList.list(
              children: [
                const Text(
                  'Available Services',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 13),
                ...services.map(
                  (service) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ServiceCard(item: service),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item});
  final _ServiceItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.rehabSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: context.rehabBorder),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => item.destination),
        ),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: item.colors,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: item.colors.first.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: context.rehabMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.colors.first.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: item.colors.first,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
    required this.destination,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final Widget destination;
}
