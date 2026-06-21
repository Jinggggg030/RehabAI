import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

class RecordSessionDialog extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final int? chatSessionId;
  final int? physioId;

  const RecordSessionDialog({
    super.key,
    required this.appointment,
    this.chatSessionId,
    this.physioId,
  });

  @override
  State<RecordSessionDialog> createState() => _RecordSessionDialogState();
}

class _RecordSessionDialogState extends State<RecordSessionDialog> {
  final _prescriptionController = TextEditingController();
  final _evaluationController = TextEditingController();

  List<dynamic> _availableExercises = [];
  final List<Map<String, dynamic>> _selectedExercises = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchExercises();
  }

  Future<void> _fetchExercises() async {
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/exercises'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _availableExercises = data['exercises'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching exercises: $e");
      setState(() => _isLoading = false);
    }
  }

  void _addExercise() {
    if (_availableExercises.isEmpty) return;
    setState(() {
      _selectedExercises.add({
        "exercise_id": _availableExercises.first['exercise_id'],
        "assigned_sets": 3,
        "assigned_duration": 30,
        "assigned_reps": 10,
        "assigned_days": 7,
        "assigned_tracking_mode": "duration",
        "evaluation": "",
      });
    });
  }

  Future<void> _submitSession() async {
    if (_prescriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a prescription/diagnosis.')),
      );
      return;
    }
    final invalidExercise = _selectedExercises.any((exercise) {
      final mode = exercise['assigned_tracking_mode']?.toString() ?? 'duration';
      final target = mode == 'reps'
          ? exercise['assigned_reps']
          : exercise['assigned_duration'];
      return (exercise['assigned_sets'] as int? ?? 0) < 1 ||
          (exercise['assigned_days'] as int? ?? 0) < 1 ||
          (target as int? ?? 0) < 1;
    });
    if (invalidExercise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercise days, sets, and target must be at least 1.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final payload = {
        "prescription": _prescriptionController.text,
        "evaluation": _evaluationController.text.isNotEmpty
            ? _evaluationController.text
            : null,
        "exercises": _selectedExercises,
        if (widget.chatSessionId != null) "physio_id": widget.physioId,
      };

      final res = await http.post(
        Uri.parse(
          widget.chatSessionId == null
              ? '$apiUrl/physio/appointments/${widget.appointment['appointment_id']}/prescribe'
              : '$apiUrl/physio/chats/${widget.chatSessionId}/prescribe',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed: ${res.body}')));
        }
      }
    } catch (e) {
      debugPrint("Error submitting session: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Map<String, dynamic>? _exerciseDetails(int? exerciseId) {
    for (final item in _availableExercises) {
      if (item['exercise_id'] == exerciseId) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  bool _supportsTrackingChoice(Map<String, dynamic>? exercise) {
    final aiType = exercise?['ai_type']?.toString().toLowerCase();
    return exercise?['requires_ai'] == true &&
        (aiType == 'rep_count' || aiType == 'rep_counter');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.chatSessionId == null
                      ? "Record Session"
                      : "Record Teleconsultation Prescription",
                  style: GoogleFonts.readexPro(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Patient: ${widget.appointment['student_name']}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _prescriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Diagnosis & Prescription Notes *',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _evaluationController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Evaluation (Time taken, rounds, feedback)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Assigned Exercises",
                          style: GoogleFonts.readexPro(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addExercise,
                          icon: const Icon(Icons.add),
                          label: const Text("Add Exercise"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedExercises.isEmpty)
                      const Text(
                        "No exercises assigned yet.",
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      ..._selectedExercises.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> ex = entry.value;
                        final exerciseDetails = _exerciseDetails(
                          ex['exercise_id'] as int?,
                        );
                        final canChooseTracking = _supportsTrackingChoice(
                          exerciseDetails,
                        );
                        final trackingMode = canChooseTracking
                            ? (ex['assigned_tracking_mode']?.toString() ??
                                  'duration')
                            : 'duration';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        key: ValueKey('exercise-$index'),
                                        decoration: const InputDecoration(
                                          labelText: 'Select Exercise',
                                          isDense: true,
                                        ),
                                        initialValue: ex['exercise_id'],
                                        items: _availableExercises
                                            .map<DropdownMenuItem<int>>((a) {
                                              return DropdownMenuItem<int>(
                                                value: a['exercise_id'],
                                                child: Text(
                                                  a['name'] ?? 'Unknown',
                                                ),
                                              );
                                            })
                                            .toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedExercises[index]['exercise_id'] =
                                                val!;
                                            if (!_supportsTrackingChoice(
                                              _exerciseDetails(val),
                                            )) {
                                              _selectedExercises[index]['assigned_tracking_mode'] =
                                                  'duration';
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => _selectedExercises.removeAt(
                                            index,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey(
                                          'days-$index-${ex['exercise_id']}',
                                        ),
                                        initialValue: ex['assigned_days']
                                            .toString(),
                                        decoration: const InputDecoration(
                                          labelText: 'Plan length (days)',
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) =>
                                            _selectedExercises[index]['assigned_days'] =
                                                int.tryParse(val) ?? 0,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey(
                                          'sets-$index-${ex['exercise_id']}',
                                        ),
                                        initialValue: ex['assigned_sets']
                                            .toString(),
                                        decoration: const InputDecoration(
                                          labelText: 'Sets',
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) =>
                                            _selectedExercises[index]['assigned_sets'] =
                                                int.tryParse(val) ?? 0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (canChooseTracking) ...[
                                  DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'mode-$index-${ex['exercise_id']}-$trackingMode',
                                    ),
                                    initialValue: trackingMode,
                                    decoration: const InputDecoration(
                                      labelText: 'Track each set by',
                                      isDense: true,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'reps',
                                        child: Text('Repetitions'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'duration',
                                        child: Text('Duration'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(
                                          () =>
                                              _selectedExercises[index]['assigned_tracking_mode'] =
                                                  value,
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  key: ValueKey(
                                    'target-$index-$trackingMode-${ex['exercise_id']}',
                                  ),
                                  initialValue: trackingMode == 'reps'
                                      ? ex['assigned_reps'].toString()
                                      : ex['assigned_duration'].toString(),
                                  decoration: InputDecoration(
                                    labelText: trackingMode == 'reps'
                                        ? 'Repetitions per set'
                                        : 'Duration per set (seconds)',
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    final parsed = int.tryParse(val) ?? 0;
                                    if (trackingMode == 'reps') {
                                      _selectedExercises[index]['assigned_reps'] =
                                          parsed;
                                    } else {
                                      _selectedExercises[index]['assigned_duration'] =
                                          parsed;
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  initialValue: ex['evaluation'],
                                  decoration: const InputDecoration(
                                    labelText: 'Exercise Notes/Goals',
                                    isDense: true,
                                  ),
                                  onChanged: (val) =>
                                      _selectedExercises[index]['evaluation'] =
                                          val,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.chatSessionId == null
                              ? "Submit Session"
                              : "Save Prescription",
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
