import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:rehab_ai/screens/physiotherapist/student_profile_dialog.dart';

class PhysioProgressTab extends StatefulWidget {
  final int physioId;

  const PhysioProgressTab({super.key, required this.physioId});

  @override
  State<PhysioProgressTab> createState() => _PhysioProgressTabState();
}

class _PhysioProgressTabState extends State<PhysioProgressTab> {
  final String _apiUrl = kIsWeb
      ? 'http://127.0.0.1:8000'
      : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _patients = [];
  Map<String, dynamic>? _selectedPatient;
  Map<String, dynamic>? _progress;
  bool _loadingPatients = true;
  bool _loadingProgress = false;
  String _searchTerm = '';
  String? _error;
  int? _selectedAppointmentId;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _loadingPatients = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/physio/patients/${widget.physioId}'),
      );
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final patients = (body['patients'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((patient) => Map<String, dynamic>.from(patient))
          .toList();
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _loadingPatients = false;
      });
      if (patients.isNotEmpty) {
        final selectedId = _selectedPatient?['student_id'];
        final patient = patients.cast<Map<String, dynamic>>().firstWhere(
          (item) => item['student_id'] == selectedId,
          orElse: () => patients.first,
        );
        await _selectPatient(patient);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPatients = false;
        _error = 'Unable to load assigned patients.';
      });
      debugPrint('Physio patient progress error: $error');
    }
  }

  Future<void> _selectPatient(Map<String, dynamic> patient) async {
    setState(() {
      _selectedPatient = patient;
      _loadingProgress = true;
      _progress = null;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse(
          '$_apiUrl/physio/${widget.physioId}/patients/'
          '${patient['student_id']}/progress',
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
      if (!mounted ||
          _selectedPatient?['student_id'] != patient['student_id']) {
        return;
      }
      setState(() {
        _progress = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        final appointments = _progress!['appointments'] as List<dynamic>?;
        if (appointments != null && appointments.isNotEmpty) {
          _selectedAppointmentId = appointments.first['appointment_id'] as int?;
        } else {
          _selectedAppointmentId = null;
        }
        _loadingProgress = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingProgress = false;
        _error = 'Unable to load progress for this patient.';
      });
      debugPrint('Patient analysis error: $error');
    }
  }

  List<Map<String, dynamic>> get _visiblePatients {
    if (_searchTerm.isEmpty) return _patients;
    return _patients.where((patient) {
      final name = patient['student_name']?.toString().toLowerCase() ?? '';
      final email = patient['email']?.toString().toLowerCase() ?? '';
      return name.contains(_searchTerm) || email.contains(_searchTerm);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1400;
    return Row(
      children: [
        _buildPatientSidebar(compact: compact),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: _buildAnalysisArea()),
      ],
    );
  }

  Widget _buildPatientSidebar({required bool compact}) {
    return Container(
      width: compact ? 260 : 310,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Patient Analysis',
                      style: GoogleFonts.readexPro(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _fetchPatients,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchTerm = value.trim().toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search patients',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF4F6F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loadingPatients
                ? const Center(child: CircularProgressIndicator())
                : _visiblePatients.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No assigned patients found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _visiblePatients.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final patient = _visiblePatients[index];
                      final selected =
                          patient['student_id'] ==
                          _selectedPatient?['student_id'];
                      return ListTile(
                        selected: selected,
                        selectedTileColor: Colors.blue.withValues(alpha: 0.08),
                        leading: CircleAvatar(
                          backgroundColor: selected
                              ? Colors.blue[100]
                              : Colors.grey[200],
                          child: Icon(
                            Icons.person,
                            color: selected ? Colors.blue[800] : Colors.grey,
                          ),
                        ),
                        title: Text(
                          patient['student_name']?.toString() ?? 'Patient',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          patient['active_prescription']?.toString() ??
                              'No active prescription',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _selectPatient(patient),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisArea() {
    if (_loadingPatients) return const SizedBox.shrink();
    if (_patients.isEmpty) {
      return const Center(child: Text('Assign a patient to begin monitoring.'));
    }
    if (_loadingProgress) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _selectedPatient == null
                  ? _fetchPatients
                  : () => _selectPatient(_selectedPatient!),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    final progress = _progress;
    if (progress == null) {
      return const Center(child: Text('Select a patient to view progress.'));
    }

    final appointments = progress['appointments'] as List<dynamic>? ?? [];
    final selectedAppt = appointments.firstWhere(
      (dynamic appt) => appt['appointment_id'] == _selectedAppointmentId,
      orElse: () => appointments.isNotEmpty ? appointments.first : null,
    ) as Map<String, dynamic>?;

    return RefreshIndicator(
      onRefresh: () => _selectPatient(_selectedPatient!),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(26),
        children: [
          _buildPatientHeader(progress),
          const SizedBox(height: 16),
          _buildTimelineSelector(progress),
          const SizedBox(height: 22),
          _buildSummaryCards(selectedAppt),
          const SizedBox(height: 22),
          _buildPainInsight(selectedAppt),
          const SizedBox(height: 22),
          _buildWeeklyActivity(selectedAppt),
          const SizedBox(height: 22),
          _buildExercisePerformance(progress),
          const SizedBox(height: 22),
          _buildRecentSessions(selectedAppt),
        ],
      ),
    );
  }

  Widget _buildTimelineSelector(Map<String, dynamic> progress) {
    final appointments = progress['appointments'] as List<dynamic>? ?? [];
    if (appointments.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Text(
          'Treatment Plan History:',
          style: GoogleFonts.readexPro(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: _selectedAppointmentId,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedAppointmentId = newValue;
                    });
                  }
                },
                items: appointments.map<DropdownMenuItem<int>>((dynamic appt) {
                  final dateStr = appt['date']?.toString();
                  final latestDateStr = appt['latest_date']?.toString();
                  String dateLabel = 'Unknown Date';
                  if (dateStr != null) {
                    try {
                      final dt = DateTime.parse(dateStr);
                      if (latestDateStr != null && latestDateStr != dateStr) {
                        final ldt = DateTime.parse(latestDateStr);
                        dateLabel = '${DateFormat('MMM d, yyyy').format(dt)} to ${DateFormat('MMM d, yyyy').format(ldt)}';
                      } else {
                        dateLabel = DateFormat('MMM d, yyyy').format(dt);
                      }
                    } catch (_) {}
                  }

                  String details = '';
                  final subject = appt['subject']?.toString().trim() ?? '';
                  if (subject.isNotEmpty) {
                    details = subject;
                  }

                  if (details.isEmpty) {
                    final exercises = appt['assigned_exercises'] as List<dynamic>? ?? [];
                    if (exercises.isNotEmpty) {
                      final names = exercises
                          .map((dynamic ex) => ex['name']?.toString() ?? '')
                          .where((name) => name.isNotEmpty)
                          .toSet()
                          .toList();
                      if (names.isNotEmpty) {
                        details = names.join(', ');
                      }
                    }
                  }

                  final triage = appt['triage_data'] as Map?;
                  if (triage != null && triage['pain_area'] != null) {
                    final area = triage['pain_area'].toString().trim();
                    if (area.isNotEmpty) {
                      if (details.isNotEmpty) {
                        details = '$details ($area)';
                      } else {
                        details = '$area Rehab';
                      }
                    }
                  }

                  if (details.isEmpty) {
                    details = appt['status'] == 'Completed' ? 'Follow-up Rehab' : 'General Consultation';
                  }

                  String label = '$details — $dateLabel';
                  if (appointments.indexOf(appt) == 0) label += ' (Active)';
                  return DropdownMenuItem<int>(
                    value: appt['appointment_id'] as int,
                    child: Text(label),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientHeader(Map<String, dynamic> progress) {
    final patient = Map<String, dynamic>.from(progress['patient'] as Map);
    final appointments = progress['appointments'] as List<dynamic>? ?? [];
    final selectedAppt = appointments.firstWhere(
      (appt) => appt['appointment_id'] == _selectedAppointmentId,
      orElse: () => appointments.isNotEmpty ? appointments.first : null,
    );
    final prescription = selectedAppt?['prescription'];
    final profilePic = patient['profile_picture']?.toString();

    Widget identity() => Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.blue[100],
          backgroundImage: profilePic != null && profilePic.isNotEmpty
              ? NetworkImage(
                  profilePic.startsWith('http')
                      ? profilePic
                      : Supabase.instance.client.storage
                          .from('profile_picture')
                          .getPublicUrl(profilePic),
                )
              : null,
          child: profilePic == null || profilePic.isEmpty
              ? Icon(Icons.person, size: 30, color: Colors.blue[800])
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patient['student_name']?.toString() ?? 'Patient',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.readexPro(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                patient['email']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        if (patient['student_id'] != null)
          IconButton(
            tooltip: 'View Patient Profile',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => StudentProfileDialog(
                  studentId: patient['student_id'].toString(),
                ),
              );
            },
            icon: const Icon(Icons.info_outline, color: Colors.blue),
          ),
      ],
    );

    Widget prescriptionCard() => Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Prescription: $prescription',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.blue[900]),
      ),
    );

    final hasPrescription = prescription != null && prescription.toString().trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity(),
              if (hasPrescription) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: prescriptionCard(),
                ),
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: identity()),
            if (hasPrescription) ...[
              const SizedBox(width: 16),
              prescriptionCard(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic>? selectedAppt) {
    if (selectedAppt == null || selectedAppt['summary'] == null) return const SizedBox.shrink();
    final summary = Map<String, dynamic>.from(selectedAppt['summary'] as Map);
    final accuracy = (summary['average_accuracy'] as num?)?.toDouble();
    final pain = (summary['average_pain_change'] as num?)?.toDouble();
    final seconds = (summary['total_duration_minutes'] as num?)?.toInt() ?? 0;
    final cards = [
      _AnalysisCard(
        label: 'Completed Sessions',
        value: '${summary['total_sessions'] ?? 0}',
        icon: Icons.check_circle_outline,
        color: Colors.blue,
      ),
      _AnalysisCard(
        label: 'Active Minutes',
        value: seconds.toString(),
        icon: Icons.timer_outlined,
        color: Colors.indigo,
      ),
      _AnalysisCard(
        label: 'Average Accuracy',
        value: accuracy == null ? '—' : '${accuracy.toStringAsFixed(0)}%',
        icon: Icons.auto_awesome,
        color: Colors.orange,
      ),
      _AnalysisCard(
        label: 'Pain Change',
        value: pain == null
            ? '—'
            : '${pain >= 0 ? '↓' : '↑'}${pain.abs().toStringAsFixed(1)}',
        icon: Icons.monitor_heart_outlined,
        color: pain == null || pain >= 0 ? Colors.green : Colors.red,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => GridView.count(
        crossAxisCount: constraints.maxWidth < 700 ? 2 : 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: constraints.maxWidth < 700 ? 1.4 : 1.3,
        children: cards,
      ),
    );
  }

  Widget _buildPainInsight(Map<String, dynamic>? selectedAppt) {
    if (selectedAppt == null || selectedAppt['summary'] == null) return const SizedBox.shrink();
    final summary = Map<String, dynamic>.from(selectedAppt['summary'] as Map);
    final pain = (summary['average_pain_change'] as num?)?.toDouble();
    final streak = (summary['activity_streak'] as num?)?.toInt() ?? 0;
    final text = pain == null
        ? 'Not enough paired pain ratings to calculate a trend.'
        : pain >= 0
        ? 'Pain decreases by ${pain.toStringAsFixed(1)} points after exercise on average.'
        : 'Pain increases by ${pain.abs().toStringAsFixed(1)} points after exercise on average. Review exercise intensity with this patient.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pain != null && pain < 0
            ? Colors.red.withValues(alpha: 0.07)
            : Colors.green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pain != null && pain < 0
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.green.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            pain != null && pain < 0 ? Icons.warning_amber : Icons.insights,
            color: pain != null && pain < 0 ? Colors.red : Colors.green[800],
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          const SizedBox(width: 16),
          Text(
            '$streak day streak',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivity(Map<String, dynamic>? selectedAppt) {
    if (selectedAppt == null || selectedAppt['weekly_activity'] == null) return const SizedBox.shrink();
    final activity = (selectedAppt['weekly_activity'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final maxSeconds = activity.fold<int>(0, (current, item) {
      final seconds = (item['duration_seconds'] as num?)?.toInt() ?? 0;
      return seconds > current ? seconds : current;
    });
    return _SectionCard(
      title: 'Activity — Last 7 Days',
      subtitle: 'Minutes completed for assigned exercises',
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: activity.map((item) {
            final seconds = (item['duration_seconds'] as num?)?.toInt() ?? 0;
            final ratio = maxSeconds == 0 ? 0.0 : seconds / maxSeconds;
            final date = DateTime.tryParse(item['date']?.toString() ?? '');
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      seconds == 0 ? '' : (seconds / 60).toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: double.infinity,
                      height: maxSeconds == 0 ? 4 : 92 * ratio + 4,
                      decoration: BoxDecoration(
                        color: seconds == 0
                            ? Colors.grey[200]
                            : Colors.blue[700],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      date == null
                          ? '—'
                          : DateFormat('E').format(date).substring(0, 1),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildExercisePerformance(Map<String, dynamic> progress) {
    final appointments = progress['appointments'] as List<dynamic>? ?? [];
    final selectedAppt = appointments.firstWhere(
      (appt) => appt['appointment_id'] == _selectedAppointmentId,
      orElse: () => appointments.isNotEmpty ? appointments.first : null,
    );
    final exercises = (selectedAppt?['assigned_exercises'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    
    // Get global exercises list from backend to fetch global sessions count and accuracy for the assigned exercises
    final globalExercises = (progress['exercises'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return _SectionCard(
      title: 'Assigned Exercises Progress',
      subtitle: 'Performance for the selected treatment plan',
      child: exercises.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No exercises assigned for this plan.')),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Exercise')),
                  DataColumn(label: Text('Source')),
                  DataColumn(label: Text('Target')),
                  DataColumn(label: Text('Sessions')),
                  DataColumn(label: Text('Minutes')),
                  DataColumn(label: Text('Accuracy')),
                  DataColumn(label: Text('Last completed')),
                ],
                rows: exercises.map((exercise) {
                  // Find the corresponding global exercise stats for this specific exercise_id
                  final globalEx = globalExercises.firstWhere(
                    (g) => g['exercise_id'] == exercise['exercise_id'] && g['source'] == 'Assigned',
                    orElse: () => <String, dynamic>{},
                  );
                  
                  final seconds = (globalEx['total_duration_seconds'] as num?)?.toInt() ?? 0;
                  final accuracy = (globalEx['average_accuracy'] as num?)?.toDouble();
                  final last = DateTime.tryParse(globalEx['last_completed']?.toString() ?? '');

                  return DataRow(
                    cells: [
                      DataCell(Text(exercise['name']?.toString() ?? 'Exercise')),
                      DataCell(_SourceChip('Assigned')),
                      DataCell(
                        Text(
                          exercise['assigned_tracking_mode'] == 'reps'
                              ? '${exercise['assigned_sets'] ?? 0} × ${exercise['assigned_reps'] ?? 0} reps for ${exercise['assigned_days'] ?? 1} days'
                              : '${exercise['assigned_sets'] ?? 0} × ${exercise['assigned_duration'] ?? 0}s for ${exercise['assigned_days'] ?? 1} days'
                        ),
                      ),
                      DataCell(Text('${globalEx['session_count'] ?? 0}')),
                      DataCell(Text((seconds / 60).toStringAsFixed(1))),
                      DataCell(
                        Text(
                          accuracy == null ? '—' : '${accuracy.toStringAsFixed(0)}%',
                        ),
                      ),
                      DataCell(
                        Text(
                          last == null ? 'Not completed' : DateFormat('MMM dd').format(last),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildRecentSessions(Map<String, dynamic>? selectedAppt) {
    if (selectedAppt == null || selectedAppt['recent_sessions'] == null) return const SizedBox.shrink();
    final sessions = (selectedAppt['recent_sessions'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .take(8)
        .toList();
    return _SectionCard(
      title: 'Recent Sessions',
      subtitle: 'Latest outcomes for this patient',
      child: sessions.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(22),
              child: Center(child: Text('No completed sessions yet.')),
            )
          : Column(
              children: sessions.map((session) {
                final date = DateTime.tryParse(
                  session['completion_date']?.toString() ?? '',
                )?.toLocal();
                final accuracy = (session['accuracy_score'] as num?)
                    ?.toDouble();
                final painBefore = (session['pain_before'] as num?)?.toInt();
                final painAfter = (session['pain_after'] as num?)?.toInt();
                final source = session['source']?.toString() ?? 'Assigned';
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: const Icon(Icons.fitness_center, color: Colors.blue),
                  ),
                  title: Text(
                    session['exercise_name']?.toString() ?? 'Exercise',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date == null
                            ? 'Date unavailable'
                            : DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _SourceChip(source),
                          if (accuracy != null)
                            _OutcomeChip(
                              '${accuracy.toStringAsFixed(0)}% accuracy',
                            ),
                          if (painBefore != null && painAfter != null)
                            _OutcomeChip('Pain $painBefore → $painAfter'),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String source;

  const _SourceChip(this.source);

  @override
  Widget build(BuildContext context) {
    final isAssigned = source == 'Assigned';
    final color = isAssigned ? Colors.blue : Colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        source,
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final MaterialColor color;

  const _AnalysisCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color[700]),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.readexPro(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  final String label;

  const _OutcomeChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
