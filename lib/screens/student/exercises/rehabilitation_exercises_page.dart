import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exercise_details_page.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:rehab_ai/utils/current_user_id.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';

class RehabilitationExercisesPage extends StatefulWidget {
  const RehabilitationExercisesPage({super.key});

  @override
  State<RehabilitationExercisesPage> createState() =>
      _RehabilitationExercisesPageState();
}

class _RehabilitationExercisesPageState
    extends State<RehabilitationExercisesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _exploreSearchController =
      TextEditingController();
  int _activeTabIndex = 0;
  String _exploreSearchQuery = '';

  List<dynamic> allExercises = [];
  List<dynamic> assignedExercises = [];
  List<dynamic> scheduledExercises = [];
  List<dynamic> completedExercises = [];
  bool isLoading = true;

  String selectedDiscipline = 'All';
  List<String> disciplines = ['All'];

  final String apiUrl = kIsWeb
      ? 'http://127.0.0.1:8000'
      : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();

  List<dynamic> get _myExercises => [
    ...scheduledExercises.map(
      (exercise) => {
        ...Map<String, dynamic>.from(exercise),
        '_source': 'scheduled',
      },
    ),
    ...assignedExercises.map(
      (exercise) => {
        ...Map<String, dynamic>.from(exercise),
        '_source': 'assigned',
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchExercises();
  }

  void _handleTabChange() {
    if (!mounted || _activeTabIndex == _tabController.index) return;
    setState(() => _activeTabIndex = _tabController.index);
  }

  Future<void> _scheduleExercise(Map<String, dynamic> exercise) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1565C0),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0)),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        final dt = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() => isLoading = true);
        try {
          final studentId = await getCurrentBackendUserId();
          final res = await http.post(
            Uri.parse('$apiUrl/students/$studentId/scheduled_exercises'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'exercise_id': exercise['exercise_id'],
              'scheduled_date': dt.toIso8601String(),
            }),
          );
          if (res.statusCode == 200) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exercise scheduled successfully!'),
                ),
              );
              await _fetchExercises();
              if (mounted) _tabController.animateTo(0);
            }
          }
        } catch (e) {
          debugPrint("Schedule error: $e");
        } finally {
          setState(() => isLoading = false);
        }
      }
    }
  }

  Future<void> _cancelScheduledExercise(int scheduledId) async {
    setState(() => isLoading = true);
    try {
      final res = await http.put(
        Uri.parse('$apiUrl/scheduled_exercises/$scheduledId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'Cancelled'}),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Scheduled exercise cancelled')),
          );
          _fetchExercises(); // Refresh plan
        }
      }
    } catch (e) {
      debugPrint("Cancel error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchExercises() async {
    try {
      final studentId = await getCurrentBackendUserId();
      // Fetch all exercises
      final resAll = await http.get(Uri.parse('$apiUrl/exercises'));
      if (resAll.statusCode == 200) {
        final fetchedExercises = jsonDecode(resAll.body)['exercises'] ?? [];

        // Extract unique disciplines
        final Set<String> discSet = {'All'};
        for (var ex in fetchedExercises) {
          if (ex['disciplines'] != null && ex['disciplines'] is List) {
            for (var d in ex['disciplines']) {
              discSet.add(d.toString());
            }
          }
        }

        setState(() {
          allExercises = fetchedExercises;
          disciplines = discSet.toList()
            ..sort(
              (a, b) => a == 'All' ? -1 : (b == 'All' ? 1 : a.compareTo(b)),
            );
        });
      }

      // Fetch exercises belonging to the authenticated student.
      final resAssigned = await http.get(
        Uri.parse('$apiUrl/students/$studentId/prescribed_exercises'),
      );
      if (resAssigned.statusCode == 200) {
        setState(() {
          assignedExercises = jsonDecode(resAssigned.body)['exercises'] ?? [];
        });
      }

      // Fetch self-scheduled exercises
      final resScheduled = await http.get(
        Uri.parse('$apiUrl/students/$studentId/scheduled_exercises'),
      );
      if (resScheduled.statusCode == 200) {
        setState(() {
          scheduledExercises =
              jsonDecode(resScheduled.body)['scheduled_exercises'] ?? [];
        });
      }

      final resCompleted = await http.get(
        Uri.parse('$apiUrl/students/$studentId/completed_exercises'),
      );
      if (resCompleted.statusCode == 200) {
        setState(() {
          completedExercises =
              jsonDecode(resCompleted.body)['completed_exercises'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching exercises: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _exploreSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              decoration: const BoxDecoration(
                gradient: RehabColors.patientGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: SizedBox(
                height: 48,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Rehabilitation Exercises',
                        style: GoogleFonts.readexPro(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RehabColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: RehabColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.all(4),
                labelColor: RehabColors.primary,
                labelStyle: GoogleFonts.readexPro(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                unselectedLabelColor: Colors.grey,
                unselectedLabelStyle: GoogleFonts.readexPro(
                  fontWeight: FontWeight.normal,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'My Exercises'),
                  Tab(text: 'Explore'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),

            if (_activeTabIndex == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: RehabColors.input,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: RehabColors.border),
                  ),
                  child: TextField(
                    controller: _exploreSearchController,
                    onChanged: (value) {
                      setState(() => _exploreSearchQuery = value.trim());
                    },
                    decoration: InputDecoration(
                      hintText: 'Search exercises',
                      hintStyle: GoogleFonts.readexPro(
                        color: RehabColors.subtle,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: RehabColors.primary,
                      ),
                      suffixIcon: _exploreSearchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _exploreSearchController.clear();
                                setState(() => _exploreSearchQuery = '');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: RehabColors.muted,
                              ),
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),

            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: disciplines.map((disc) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedDiscipline = disc;
                          });
                        },
                        child: _buildFilterChip(
                          disc,
                          isSelected: selectedDiscipline == disc,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Prescribed and self-scheduled pending exercises
                        _buildExercisesList(
                          _myExercises.where((ex) {
                            if (selectedDiscipline == 'All') return true;
                            if (ex['disciplines'] != null &&
                                ex['disciplines'] is List) {
                              return (ex['disciplines'] as List).contains(
                                selectedDiscipline,
                              );
                            }
                            return false;
                          }).toList(),
                          tabType: 'MyExercises',
                        ),
                        // Explore Tab
                        _buildExercisesList(
                          allExercises.where((ex) {
                            final matchesDiscipline =
                                selectedDiscipline == 'All' ||
                                (ex['disciplines'] is List &&
                                    (ex['disciplines'] as List).contains(
                                      selectedDiscipline,
                                    ));
                            final query = _exploreSearchQuery.toLowerCase();
                            final matchesSearch =
                                query.isEmpty ||
                                (ex['name'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(query) ||
                                (ex['description'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(query);
                            return matchesDiscipline && matchesSearch;
                          }).toList(),
                          tabType: 'Explore',
                        ),
                        // Completed Tab
                        _buildExercisesList(
                          completedExercises.where((ex) {
                            if (selectedDiscipline == 'All') return true;
                            if (ex['disciplines'] != null &&
                                ex['disciplines'] is List) {
                              return (ex['disciplines'] as List).contains(
                                selectedDiscipline,
                              );
                            }
                            return false;
                          }).toList(),
                          tabType: 'Completed',
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String text, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.readexPro(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? const Color(0xFF1565C0) : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildExercisesList(
    List<dynamic> exercises, {
    required String tabType,
  }) {
    if (exercises.isEmpty) {
      return Center(
        child: Text(
          tabType == 'MyExercises'
              ? 'No assigned or scheduled exercises.'
              : tabType == 'Completed'
              ? 'No completed exercises yet.'
              : _exploreSearchQuery.isNotEmpty
              ? 'No exercises match your search.'
              : 'No exercises found for this discipline.',
          style: GoogleFonts.readexPro(
            color: Colors.grey.shade500,
            fontSize: 16,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
      itemCount: exercises.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildExerciseCard(exercises[index], tabType: tabType);
      },
    );
  }

  Widget _buildExerciseCard(
    Map<String, dynamic> exercise, {
    required String tabType,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RehabColors.border),
        boxShadow: [
          BoxShadow(
            color: RehabColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Discipline
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (exercise['disciplines'] != null &&
                  (exercise['disciplines'] as List).isNotEmpty)
                ...(exercise['disciplines'] as List).map<Widget>(
                  (d) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      d.toString(),
                      style: GoogleFonts.readexPro(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'General',
                    style: GoogleFonts.readexPro(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                ),
              if (exercise['requires_ai'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (exercise['ai_type'] ?? 'AI').toString().toUpperCase(),
                    style: GoogleFonts.readexPro(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Exercise Name
          Text(
            exercise['name'] ?? 'Unknown Exercise',
            style: GoogleFonts.readexPro(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (tabType == 'MyExercises' &&
              exercise['_source'] == 'assigned') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _buildInfoItem(
                  Icons.calendar_today,
                  exercise['assigned_date'] != null
                      ? DateFormat(
                          'MMM dd, yyyy',
                        ).format(DateTime.parse(exercise['assigned_date']))
                      : 'Unknown date',
                ),
                _buildInfoItem(
                  Icons.date_range_outlined,
                  '${exercise['assigned_days'] ?? 1} days',
                ),
                _buildInfoItem(
                  Icons.layers_outlined,
                  '${exercise['assigned_sets'] ?? 0} Sets',
                ),
                _buildInfoItem(
                  exercise['assigned_tracking_mode'] == 'reps'
                      ? Icons.repeat
                      : Icons.timer_outlined,
                  exercise['assigned_tracking_mode'] == 'reps'
                      ? '${exercise['assigned_reps'] ?? 0} reps per set'
                      : '${exercise['assigned_duration'] ?? 0} sec per set',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAssignmentProgress(exercise),
          ] else if (tabType == 'MyExercises' &&
              exercise['_source'] == 'scheduled') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  exercise['scheduled_date'] != null
                      ? DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format(DateTime.parse(exercise['scheduled_date']))
                      : 'Unknown date',
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.info_outline, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Status: ${exercise['status'] ?? 'Pending'}',
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ] else if (tabType == 'Completed') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _buildInfoItem(
                  Icons.check_circle_outline,
                  exercise['completion_date'] != null
                      ? DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format(DateTime.parse(exercise['completion_date']))
                      : 'Completed',
                ),
                if (exercise['completed_sets'] != null)
                  _buildInfoItem(
                    Icons.layers_outlined,
                    '${exercise['completed_sets']} sets',
                  ),
                if (exercise['completed_reps'] != null)
                  _buildInfoItem(
                    Icons.repeat,
                    '${exercise['completed_reps']} reps',
                  ),
                if (exercise['duration_seconds'] != null)
                  _buildInfoItem(
                    Icons.timer_outlined,
                    _formatDuration(exercise['duration_seconds']),
                  ),
                if (exercise['accuracy_score'] != null)
                  _buildInfoItem(
                    Icons.auto_awesome,
                    '${(exercise['accuracy_score'] as num).toStringAsFixed(0)}% accuracy',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Details and Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  (exercise['description'] ?? '').toString().replaceAll(
                    '\n',
                    ' ',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              if (tabType != 'Completed') ...[
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tabType == 'Explore') ...[
                      OutlinedButton(
                        onPressed: () => _scheduleExercise(exercise),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(color: Color(0xFF1565C0)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Schedule',
                          style: GoogleFonts.readexPro(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (tabType == 'MyExercises' &&
                        exercise['_source'] == 'scheduled') ...[
                      OutlinedButton(
                        onPressed: () =>
                            _cancelScheduledExercise(exercise['schedule_id']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.readexPro(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExerciseDetailsPage(
                              isAssigned: exercise['_source'] == 'assigned',
                              exercise: exercise,
                              scheduleId: exercise['schedule_id'],
                            ),
                          ),
                        );
                        if (mounted) await _fetchExercises();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Perform Now',
                        style: GoogleFonts.readexPro(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.readexPro(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentProgress(Map<String, dynamic> exercise) {
    final totalDays = (exercise['assigned_days'] as num?)?.toInt() ?? 1;
    final currentDay = (exercise['plan_day'] as num?)?.toInt() ?? 1;
    final daysLeft = (exercise['days_remaining'] as num?)?.toInt() ?? totalDays;
    final progress =
        ((exercise['plan_progress'] as num?)?.toDouble() ??
                (currentDay / totalDays))
            .clamp(0.0, 1.0);
    final isUpcoming = currentDay == 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RehabColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_view_week_rounded,
                size: 17,
                color: RehabColors.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  isUpcoming
                      ? 'Plan starts soon'
                      : 'Day $currentDay of $totalDays',
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RehabColors.ink,
                  ),
                ),
              ),
              Text(
                '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left',
                style: GoogleFonts.readexPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: RehabColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(RehabColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(dynamic secondsValue) {
    final seconds = (secondsValue as num).toInt();
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return minutes > 0 ? '${minutes}m ${remainder}s' : '${remainder}s';
  }
}
