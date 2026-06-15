import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

class RecordSessionDialog extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const RecordSessionDialog({super.key, required this.appointment});

  @override
  State<RecordSessionDialog> createState() => _RecordSessionDialogState();
}

class _RecordSessionDialogState extends State<RecordSessionDialog> {
  final _prescriptionController = TextEditingController();
  final _evaluationController = TextEditingController();
  
  List<dynamic> _availableExercises = [];
  List<Map<String, dynamic>> _selectedExercises = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchExercises();
  }

  Future<void> _fetchExercises() async {
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
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
        "assigned_duration": 15,
        "evaluation": ""
      });
    });
  }

  Future<void> _submitSession() async {
    if (_prescriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a prescription/diagnosis.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final payload = {
        "prescription": _prescriptionController.text,
        "evaluation": _evaluationController.text.isNotEmpty ? _evaluationController.text : null,
        "exercises": _selectedExercises
      };
      
      final res = await http.post(
        Uri.parse('$apiUrl/physio/appointments/${widget.appointment['appointment_id']}/prescribe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      
      if (res.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${res.body}')));
        }
      }
    } catch (e) {
      debugPrint("Error submitting session: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
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
                Text("Record Session", style: GoogleFonts.readexPro(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 8),
            Text("Patient: ${widget.appointment['student_name']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        Text("Assigned Exercises", style: GoogleFonts.readexPro(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _addExercise,
                          icon: const Icon(Icons.add),
                          label: const Text("Add Exercise"),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedExercises.isEmpty)
                      const Text("No exercises assigned yet.", style: TextStyle(color: Colors.grey))
                    else
                      ..._selectedExercises.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> ex = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        decoration: const InputDecoration(labelText: 'Select Exercise', isDense: true),
                                        value: ex['exercise_id'],
                                        items: _availableExercises.map<DropdownMenuItem<int>>((a) {
                                          return DropdownMenuItem<int>(
                                            value: a['exercise_id'],
                                            child: Text(a['name'] ?? 'Unknown'),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() => _selectedExercises[index]['exercise_id'] = val!);
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() => _selectedExercises.removeAt(index));
                                      },
                                    )
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: ex['assigned_sets'].toString(),
                                        decoration: const InputDecoration(labelText: 'Sets', isDense: true),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) => _selectedExercises[index]['assigned_sets'] = int.tryParse(val) ?? 0,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: ex['assigned_duration'].toString(),
                                        decoration: const InputDecoration(labelText: 'Duration (secs)', isDense: true),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) => _selectedExercises[index]['assigned_duration'] = int.tryParse(val) ?? 0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  initialValue: ex['evaluation'],
                                  decoration: const InputDecoration(labelText: 'Exercise Notes/Goals', isDense: true),
                                  onChanged: (val) => _selectedExercises[index]['evaluation'] = val,
                                )
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                  child: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Submit Session"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
