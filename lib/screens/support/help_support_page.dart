import 'package:flutter/material.dart';
import 'package:rehab_ai/screens/support/contact_us_page.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RehabColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
                children: [
                  const Text(
                    'How can we help?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Get in touch with us or learn common physiotherapy terms.',
                    style: TextStyle(
                      color: RehabColors.muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _HelpTile(
                    title: 'Contact Us',
                    subtitle: 'Contact the UTeM Healthcare Centre',
                    icon: Icons.support_agent_rounded,
                    colors: const [Color(0xFFF59E0B), Color(0xFFF97316)],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactUsPage()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HelpTile(
                    title: 'Physiotherapy Dictionary',
                    subtitle: 'Understand disciplines and rehabilitation terms',
                    icon: Icons.menu_book_rounded,
                    colors: const [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PhysiotherapyDictionaryPage(),
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
}

class PhysiotherapyDictionaryPage extends StatelessWidget {
  const PhysiotherapyDictionaryPage({super.key});

  static const _disciplines = <_Discipline>[
    _Discipline(
      name: 'Cardiorespiratory',
      summary: 'Heart and lung rehabilitation',
      description:
          'Helps improve breathing, stamina and physical function for people with heart or lung conditions, or after prolonged illness.',
      icon: Icons.monitor_heart_rounded,
      color: Color(0xFFEF4444),
    ),
    _Discipline(
      name: 'Orthopaedic',
      summary: 'Muscles, bones and joints',
      description:
          'Treats pain or movement problems involving muscles, bones, joints, ligaments and tendons, including recovery after injury or surgery.',
      icon: Icons.accessibility_new_rounded,
      color: Color(0xFF2563EB),
    ),
    _Discipline(
      name: 'Neurological',
      summary: 'Brain, spinal cord and nerves',
      description:
          'Supports movement, balance and independence for people affected by conditions such as stroke, spinal cord injury or nerve disorders.',
      icon: Icons.psychology_rounded,
      color: Color(0xFF8B5CF6),
    ),
    _Discipline(
      name: 'Sports',
      summary: 'Sports injury and performance recovery',
      description:
          'Focuses on preventing and treating exercise-related injuries, restoring strength and safely returning a person to activity or sport.',
      icon: Icons.sports_gymnastics_rounded,
      color: Color(0xFF059669),
    ),
    _Discipline(
      name: 'Ergonomic',
      summary: 'Posture and everyday movement',
      description:
          'Improves how the body moves during work and daily activities to reduce strain, correct posture and prevent repeated-stress injuries.',
      icon: Icons.chair_alt_rounded,
      color: Color(0xFFF59E0B),
    ),
    _Discipline(
      name: 'General Rehabilitation',
      summary: 'Overall mobility and physical recovery',
      description:
          'Covers broad exercises for flexibility, strength, balance and function when treatment is not limited to one specialist discipline.',
      icon: Icons.health_and_safety_rounded,
      color: Color(0xFF0891B2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RehabColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: 'Physiotherapy Dictionary',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                itemCount: _disciplines.length + 1,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Physiotherapy disciplines describe the area of health and movement that a treatment focuses on.',
                        style: TextStyle(
                          color: RehabColors.muted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    );
                  }
                  return _DictionaryCard(item: _disciplines[index - 1]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, this.title = 'Help & Support'});

  final VoidCallback onBack;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: RehabColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 27),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: RehabColors.muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: RehabColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DictionaryCard extends StatelessWidget {
  const _DictionaryCard({required this.item});

  final _Discipline item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RehabColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.summary,
                  style: TextStyle(
                    color: item.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: RehabColors.muted,
                    fontSize: 12,
                    height: 1.5,
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

class _Discipline {
  const _Discipline({
    required this.name,
    required this.summary,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String name;
  final String summary;
  final String description;
  final IconData icon;
  final Color color;
}
