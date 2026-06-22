import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rehab_ai/widgets/notification_bell.dart';
import '../utils/current_user_id.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';

enum _ProgressRange { sevenDays, thirtyDays, allTime }

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final String _apiUrl = kIsWeb
      ? 'http://127.0.0.1:8000'
      : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();

  List<Map<String, dynamic>> _sessions = [];
  _ProgressRange _selectedRange = _ProgressRange.thirtyDays;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  Future<void> _fetchProgress() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final studentId = await getCurrentBackendUserId();
      final response = await http.get(
        Uri.parse('$_apiUrl/students/$studentId/completed_exercises'),
      );
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = decoded['completed_exercises'] as List<dynamic>? ?? [];
      final sessions =
          items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
            ..sort((a, b) {
              final aDate =
                  _sessionDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate =
                  _sessionDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });

      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load progress. Check the backend connection.';
      });
      debugPrint('Progress loading error: $error');
    }
  }

  List<Map<String, dynamic>> get _filteredSessions {
    final cutoff = switch (_selectedRange) {
      _ProgressRange.sevenDays => DateTime.now().subtract(
        const Duration(days: 7),
      ),
      _ProgressRange.thirtyDays => DateTime.now().subtract(
        const Duration(days: 30),
      ),
      _ProgressRange.allTime => null,
    };
    if (cutoff == null) return _sessions;
    return _sessions.where((session) {
      final date = _sessionDate(session);
      return date != null && !date.isBefore(cutoff);
    }).toList();
  }

  int get _totalSeconds => _filteredSessions.fold(
    0,
    (total, session) =>
        total + ((session['duration_seconds'] as num?)?.toInt() ?? 0),
  );

  double? get _averageAccuracy {
    final values = _filteredSessions
        .map((session) => (session['accuracy_score'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? get _averagePainChange {
    final changes = <double>[];
    for (final session in _filteredSessions) {
      final before = (session['pain_before'] as num?)?.toDouble();
      final after = (session['pain_after'] as num?)?.toDouble();
      if (before != null && after != null) changes.add(before - after);
    }
    if (changes.isEmpty) return null;
    return changes.reduce((a, b) => a + b) / changes.length;
  }

  int get _currentStreak {
    final days =
        _sessions
            .map(_sessionDate)
            .whereType<DateTime>()
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;

    var streak = 1;
    var expected = days.first.subtract(const Duration(days: 1));
    for (final day in days.skip(1)) {
      if (day == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (day.isBefore(expected)) {
        break;
      }
    }
    return streak;
  }

  List<_DailyActivity> get _lastSevenDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      final seconds = _sessions
          .where((session) {
            final date = _sessionDate(session);
            return date != null &&
                date.year == day.year &&
                date.month == day.month &&
                date.day == day.day;
          })
          .fold<int>(
            0,
            (total, session) =>
                total + ((session['duration_seconds'] as num?)?.toInt() ?? 0),
          );
      return _DailyActivity(day: day, minutes: seconds / 60);
    });
  }

  DateTime? _sessionDate(Map<String, dynamic> session) {
    final value = session['completion_date']?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF1565C0),
          onRefresh: _fetchProgress,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_isLoading)
                      const SizedBox(
                        height: 420,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      )
                    else if (_errorMessage != null)
                      _buildErrorState()
                    else if (_sessions.isEmpty)
                      _buildEmptyState()
                    else ...[
                      _buildRangeSelector(),
                      const SizedBox(height: 20),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      _buildInsightCard(),
                      const SizedBox(height: 20),
                      _buildActivityChart(),
                      const SizedBox(height: 28),
                      _buildRecentSessions(),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final completion = _sessions.isEmpty
        ? 0.0
        : (_filteredSessions.length / _sessions.length).clamp(0.0, 1.0);
    return Container(
      height: 215,
      padding: const EdgeInsets.fromLTRB(24, 52, 20, 24),
      decoration: const BoxDecoration(
        gradient: RehabColors.progressGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -60,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress Intelligence',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your recovery data, transformed into insights.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const IconTheme(
                      data: IconThemeData(color: Colors.white),
                      child: NotificationBell(),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sessions in selected period',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                        Text(
                          '${(completion * 100).round()}%',
                          style: const TextStyle(
                            color: Color(0xFF4ADE80),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: completion,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADE80)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector() {
    return SegmentedButton<_ProgressRange>(
      segments: const [
        ButtonSegment(value: _ProgressRange.sevenDays, label: Text('7 Days')),
        ButtonSegment(value: _ProgressRange.thirtyDays, label: Text('30 Days')),
        ButtonSegment(value: _ProgressRange.allTime, label: Text('All Time')),
      ],
      selected: {_selectedRange},
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF1565C0)
              : Colors.white,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.black87,
        ),
      ),
      onSelectionChanged: (selection) {
        setState(() => _selectedRange = selection.first);
      },
    );
  }

  Widget _buildStatsGrid() {
    final painChange = _averagePainChange;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _StatCard(
          label: 'Sessions',
          value: '${_filteredSessions.length}',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF1565C0),
        ),
        _StatCard(
          label: 'Active Minutes',
          value: (_totalSeconds / 60).toStringAsFixed(1),
          icon: Icons.timer_outlined,
          color: const Color(0xFF5267C9),
        ),
        _StatCard(
          label: 'AI Accuracy',
          value: _averageAccuracy == null
              ? '—'
              : '${_averageAccuracy!.toStringAsFixed(0)}%',
          icon: Icons.auto_awesome,
          color: const Color(0xFFE29A24),
        ),
        _StatCard(
          label: 'Pain Change',
          value: painChange == null
              ? '—'
              : '${painChange >= 0 ? '↓' : '↑'}${painChange.abs().toStringAsFixed(1)}',
          icon: Icons.monitor_heart_outlined,
          color: painChange == null || painChange >= 0
              ? const Color(0xFF3B8C6E)
              : const Color(0xFFC75151),
        ),
      ],
    );
  }

  Widget _buildInsightCard() {
    final painChange = _averagePainChange;
    final message = painChange == null
        ? 'Complete pain ratings before and after sessions to unlock your pain trend.'
        : painChange > 0
        ? 'Your pain is ${painChange.toStringAsFixed(1)} points lower after sessions on average.'
        : painChange < 0
        ? 'Pain is ${painChange.abs().toStringAsFixed(1)} points higher after sessions. Consider discussing this with your physiotherapist.'
        : 'Your pain level is unchanged immediately after sessions.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF2C9A82)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.insights, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_currentStreak day activity streak',
                  style: GoogleFonts.readexPro(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: GoogleFonts.readexPro(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity — Last 7 Days',
            style: GoogleFonts.readexPro(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Active exercise minutes',
            style: GoogleFonts.readexPro(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          _ActivityBars(days: _lastSevenDays),
        ],
      ),
    );
  }

  Widget _buildRecentSessions() {
    final sessions = _filteredSessions.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Sessions',
          style: GoogleFonts.readexPro(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          _buildNoSessionsInRange()
        else
          ...sessions.map(_buildSessionCard),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final date = _sessionDate(session);
    final seconds = (session['duration_seconds'] as num?)?.toInt();
    final reps = (session['completed_reps'] as num?)?.toInt();
    final sets = (session['completed_sets'] as num?)?.toInt();
    final accuracy = (session['accuracy_score'] as num?)?.toDouble();
    final painBefore = (session['pain_before'] as num?)?.toInt();
    final painAfter = (session['pain_after'] as num?)?.toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center, color: Color(0xFF1565C0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session['name']?.toString() ?? 'Exercise',
                  style: GoogleFonts.readexPro(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  date == null
                      ? 'Date unavailable'
                      : DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                  style: GoogleFonts.readexPro(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  children: [
                    if (sets != null) _MetricPill('$sets sets'),
                    if (reps != null) _MetricPill('$reps reps'),
                    if (seconds != null) _MetricPill(_formatDuration(seconds)),
                    if (accuracy != null)
                      _MetricPill('${accuracy.toStringAsFixed(0)}% accuracy'),
                    if (painBefore != null && painAfter != null)
                      _MetricPill('Pain $painBefore → $painAfter'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 420,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 54, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.readexPro(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _fetchProgress,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 420,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F4F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_outlined,
                size: 44,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your progress starts here',
              style: GoogleFonts.readexPro(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first exercise session to see activity, accuracy, and pain trends.',
              textAlign: TextAlign.center,
              style: GoogleFonts.readexPro(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSessionsInRange() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'No completed sessions in this period.',
        textAlign: TextAlign.center,
        style: GoogleFonts.readexPro(color: Colors.black54),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return minutes > 0 ? '${minutes}m ${remainder}s' : '${remainder}s';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.readexPro(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.readexPro(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String text;

  const _MetricPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.readexPro(fontSize: 10, color: Colors.black87),
      ),
    );
  }
}

class _DailyActivity {
  final DateTime day;
  final double minutes;

  const _DailyActivity({required this.day, required this.minutes});
}

class _ActivityBars extends StatelessWidget {
  final List<_DailyActivity> days;

  const _ActivityBars({required this.days});

  @override
  Widget build(BuildContext context) {
    final maximum = days.fold<double>(
      0,
      (current, day) => maxDouble(current, day.minutes),
    );
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final ratio = maximum == 0 ? 0.0 : day.minutes / maximum;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    day.minutes == 0 ? '' : day.minutes.toStringAsFixed(0),
                    style: GoogleFonts.readexPro(
                      fontSize: 9,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: double.infinity,
                    height: maximum == 0 ? 4 : 92 * ratio + 4,
                    decoration: BoxDecoration(
                      color: day.minutes == 0
                          ? const Color(0xFFE5E9E8)
                          : const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    DateFormat('E').format(day.day).substring(0, 1),
                    style: GoogleFonts.readexPro(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

double maxDouble(double a, double b) => a > b ? a : b;
