import 'package:flutter/material.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';
import 'package:rehab_ai/widgets/notification_bell.dart';

class FuturisticHomeDashboard extends StatelessWidget {
  const FuturisticHomeDashboard({
    super.key,
    required this.userName,
    required this.todayDate,
    required this.todaysRoutine,
    required this.quickAccess,
    required this.hasActiveChat,
    required this.adviceController,
    required this.onSubmitAdvice,
    required this.onOpenExercises,
    required this.onOpenRentals,
    required this.onOpenAppointments,
    required this.onBookAppointment,
    required this.onOpenChat,
    required this.onOpenRoutineExercise,
    required this.onOpenExercise,
  });

  final String userName;
  final String todayDate;
  final List<dynamic> todaysRoutine;
  final List<dynamic> quickAccess;
  final bool hasActiveChat;
  final TextEditingController adviceController;
  final VoidCallback onSubmitAdvice;
  final VoidCallback onOpenExercises;
  final VoidCallback onOpenRentals;
  final VoidCallback onOpenAppointments;
  final VoidCallback onBookAppointment;
  final VoidCallback onOpenChat;
  final ValueChanged<Map<String, dynamic>> onOpenRoutineExercise;
  final ValueChanged<Map<String, dynamic>> onOpenExercise;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.rehabBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 358,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _Header(userName: userName),
                  Positioned(
                    top: 188,
                    left: 20,
                    right: 20,
                    child: _HealthSummary(
                      date: todayDate,
                      exerciseCount: todaysRoutine.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            sliver: SliverList.list(
              children: [
                const _SectionTitle(title: 'Quick Access'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _QuickTile(
                      icon: Icons.forum_rounded,
                      title: hasActiveChat ? 'Live Chat' : 'AI Assessment',
                      subtitle: hasActiveChat ? 'Resume now' : 'Start now',
                      colors: const [Color(0xFF1565C0), Color(0xFF1976D2)],
                      onTap: onOpenChat,
                    ),
                    _QuickTile(
                      icon: Icons.calendar_month_rounded,
                      title: 'Appointments',
                      subtitle: 'Manage visits',
                      colors: const [Color(0xFF0891B2), Color(0xFF06B6D4)],
                      onTap: onOpenAppointments,
                    ),
                    _QuickTile(
                      icon: Icons.fitness_center_rounded,
                      title: 'Exercises',
                      subtitle: '${todaysRoutine.length} assigned',
                      colors: const [Color(0xFF059669), Color(0xFF10B981)],
                      onTap: onOpenExercises,
                    ),
                    _QuickTile(
                      icon: Icons.wheelchair_pickup_rounded,
                      title: 'Rentals',
                      subtitle: 'Equipment',
                      colors: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                      onTap: onOpenRentals,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionTitle(
                  title: "Today's Exercises",
                  action: 'See all',
                  onAction: onOpenExercises,
                ),
                const SizedBox(height: 12),
                if (todaysRoutine.isEmpty)
                  const _EmptyRoutine()
                else
                  ...todaysRoutine
                      .take(3)
                      .toList()
                      .asMap()
                      .entries
                      .map(
                        (entry) => _RoutineTile(
                          index: entry.key,
                          exercise: Map<String, dynamic>.from(entry.value),
                          onTap: onOpenRoutineExercise,
                        ),
                      ),
                const SizedBox(height: 22),
                _SectionTitle(
                  title: 'Explore Exercises',
                  action: 'Browse',
                  onAction: onOpenExercises,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 148,
                  child: quickAccess.isEmpty
                      ? const _EmptyRoutine()
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: quickAccess.length.clamp(0, 6),
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final exercise = Map<String, dynamic>.from(
                              quickAccess[index],
                            );
                            return _ExploreTile(
                              exercise: exercise,
                              color: const [
                                RehabColors.primary,
                                RehabColors.cyan,
                                RehabColors.green,
                                RehabColors.purple,
                                RehabColors.amber,
                              ][index % 5],
                              onTap: onOpenExercise,
                            );
                          },
                        ),
                ),
                const SizedBox(height: 22),
                _ChatComposer(
                  active: hasActiveChat,
                  controller: adviceController,
                  onSubmit: hasActiveChat ? onOpenChat : onSubmitAdvice,
                ),
                const SizedBox(height: 16),
                _AppointmentCard(onTap: onBookAppointment),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.userName});
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(24, 58, 20, 54),
      decoration: const BoxDecoration(gradient: RehabColors.patientGradient),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: -42,
            top: -72,
            child: _GlowOrb(size: 150, opacity: 0.08),
          ),
          const Positioned(
            left: 150,
            bottom: -70,
            child: _GlowOrb(size: 100, opacity: 0.06),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Good to see you,',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      userName.isEmpty ? 'Welcome back' : userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        _PulseDot(),
                        SizedBox(width: 8),
                        Text(
                          'Your recovery companion is online',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const _HeaderButton(child: NotificationBell()),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconTheme(
        data: const IconThemeData(color: Colors.white),
        child: child,
      ),
    );
  }
}

class _HealthSummary extends StatelessWidget {
  const _HealthSummary({required this.date, required this.exerciseCount});
  final String date;
  final int exerciseCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.rehabSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.rehabBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18204A87),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Today's Health Summary",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: RehabColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  date.split(',').last.trim(),
                  style: const TextStyle(
                    color: RehabColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: _SummaryMetric(
                  icon: Icons.favorite_rounded,
                  color: Color(0xFFEF4444),
                  background: Color(0xFFFEF2F2),
                  value: '--',
                  label: 'Pain Level',
                ),
              ),
              const Expanded(
                child: _SummaryMetric(
                  icon: Icons.accessibility_new_rounded,
                  color: RehabColors.green,
                  background: Color(0xFFECFDF5),
                  value: 'Active',
                  label: 'Mobility',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.bolt_rounded,
                  color: RehabColors.amber,
                  background: const Color(0xFFFFFBEB),
                  value: '$exerciseCount',
                  label: 'Exercises',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.color,
    required this.background,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final Color background;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: RehabColors.muted),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -20,
                child: _GlowOrb(size: 72, opacity: 0.1),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!, style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.index,
    required this.exercise,
    required this.onTap,
  });
  final int index;
  final Map<String, dynamic> exercise;
  final ValueChanged<Map<String, dynamic>> onTap;

  @override
  Widget build(BuildContext context) {
    final mode = exercise['assigned_tracking_mode']?.toString() ?? 'duration';
    final target = mode == 'reps'
        ? '${exercise['assigned_reps'] ?? 0} reps'
        : '${exercise['assigned_duration'] ?? 0}s';
    final totalDays = (exercise['assigned_days'] as num?)?.toInt() ?? 1;
    final currentDay = (exercise['plan_day'] as num?)?.toInt() ?? 1;
    final daysLeft = (exercise['days_remaining'] as num?)?.toInt() ?? totalDays;
    final progress =
        ((exercise['plan_progress'] as num?)?.toDouble() ??
                (currentDay / totalDays))
            .clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.rehabSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: context.rehabBorder),
        ),
        child: InkWell(
          onTap: () => onTap(exercise),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: RehabColors.primaryLight,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: RehabColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise['name']?.toString() ?? 'Exercise',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${exercise['assigned_sets'] ?? 0} sets × $target',
                            style: const TextStyle(
                              fontSize: 11,
                              color: RehabColors.subtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: RehabColors.primaryLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Text(
                        'Start',
                        style: TextStyle(
                          color: RehabColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Text(
                      currentDay == 0
                          ? 'Plan starts soon'
                          : 'Day $currentDay of $totalDays',
                      style: const TextStyle(
                        color: RehabColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left',
                      style: const TextStyle(
                        color: RehabColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: RehabColors.primaryLight,
                    valueColor: const AlwaysStoppedAnimation(
                      RehabColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({
    required this.exercise,
    required this.color,
    required this.onTap,
  });
  final Map<String, dynamic> exercise;
  final Color color;
  final ValueChanged<Map<String, dynamic>> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 166,
      child: Material(
        color: context.rehabSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.rehabBorder),
        ),
        child: InkWell(
          onTap: () => onTap(exercise),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.sports_gymnastics_rounded, color: color),
                ),
                const Spacer(),
                Text(
                  exercise['name']?.toString() ?? 'Exercise',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  exercise['ai_type']?.toString().replaceAll('_', ' ') ??
                      'Guided exercise',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: RehabColors.subtle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.active,
    required this.controller,
    required this.onSubmit,
  });
  final bool active;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RehabColors.primaryLight,
            RehabColors.cyan.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.rehabBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: RehabColors.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                active ? 'Your live chat is active' : 'Ask RehabAI',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (active)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.forum_rounded),
                label: const Text('Resume Live Chat'),
              ),
            )
          else
            TextField(
              controller: controller,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: 'How are you feeling today?',
                suffixIcon: IconButton(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.rehabSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.rehabBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.video_call_rounded,
                  color: RehabColors.cyan,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need a consultation?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Book an appointment with a physiotherapist.',
                      style: TextStyle(fontSize: 11, color: RehabColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: RehabColors.subtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRoutine extends StatelessWidget {
  const _EmptyRoutine();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.rehabSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.rehabBorder),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Nothing scheduled yet',
        style: TextStyle(color: RehabColors.muted),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF4ADE80),
        shape: BoxShape.circle,
      ),
    );
  }
}
