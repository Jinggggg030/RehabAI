import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/current_user_id.dart';

class SessionSummaryPage extends StatefulWidget {
  final String exerciseName;
  final int durationSeconds;
  final int? reps;
  final int? painBefore;
  final int? painAfter;
  final double? accuracyScore;
  final int exerciseId;
  final int? scheduleId;
  final int? completedSets;
  final int? plannedSets;
  final String sessionOrigin;

  const SessionSummaryPage({
    super.key,
    required this.exerciseName,
    required this.durationSeconds,
    required this.reps,
    this.painBefore,
    this.painAfter,
    this.accuracyScore,
    required this.exerciseId,
    this.scheduleId,
    this.completedSets,
    this.plannedSets,
    this.sessionOrigin = 'Self-selected',
  });

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  bool _isSaving = true;
  bool _saveSuccess = false;

  @override
  void initState() {
    super.initState();
    _saveSessionLog();
  }

  Future<void> _saveSessionLog() async {
    final String apiUrl = kIsWeb
        ? 'http://127.0.0.1:8000'
        : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();

    try {
      final studentId = await getCurrentBackendUserId();
      final bodyData = {
        'student_id': studentId,
        'exercise_id': widget.exerciseId,
        'completed_reps': widget.reps,
        'duration_seconds': widget.durationSeconds,
        'pain_before': widget.painBefore,
        'pain_after': widget.painAfter,
        'accuracy_score': widget.accuracyScore,
        'completed_sets': widget.completedSets,
        'planned_sets': widget.plannedSets,
        'session_origin': widget.sessionOrigin,
      };

      if (widget.scheduleId != null) {
        bodyData['schedule_id'] = widget.scheduleId;
      }

      final res = await http.post(
        Uri.parse('$apiUrl/session_logs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyData),
      );

      if (res.statusCode == 200) {
        setState(() {
          _isSaving = false;
          _saveSuccess = true;
        });
      } else {
        setState(() {
          _isSaving = false;
          _saveSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _saveSuccess = false;
      });
      debugPrint("Error saving session log: $e");
    }
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    if (m > 0) {
      return '$m min $s sec';
    }
    return '$s sec';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.check_circle,
                size: 80,
                color: const Color(0xFF1565C0),
              ),
              const SizedBox(height: 16),
              Text(
                'Session Summary',
                textAlign: TextAlign.center,
                style: GoogleFonts.readexPro(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Exercise Completed',
                textAlign: TextAlign.center,
                style: GoogleFonts.readexPro(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Exercise:', widget.exerciseName),
                    const Divider(height: 24),
                    _buildSummaryRow(
                      'Duration:',
                      _formatTime(widget.durationSeconds),
                    ),
                    if (widget.reps != null) ...[
                      const Divider(height: 24),
                      _buildSummaryRow('Repetitions:', '${widget.reps}'),
                    ],
                    if (widget.completedSets != null) ...[
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'Sets:',
                        '${widget.completedSets} / ${widget.plannedSets ?? widget.completedSets}',
                      ),
                    ],

                    if (widget.painBefore != null ||
                        widget.painAfter != null) ...[
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'Pain Before:',
                        '${widget.painBefore ?? '-'}/10',
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Pain After:',
                        '${widget.painAfter ?? '-'}/10',
                      ),
                    ],

                    if (widget.accuracyScore != null) ...[
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'AI Accuracy:',
                        '${widget.accuracyScore!.toStringAsFixed(1)}%',
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              if (_isSaving)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                )
              else if (_saveSuccess)
                Text(
                  'âœ“ Progress securely saved',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.readexPro(
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Text(
                  'âŒ Failed to save progress to cloud',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.readexPro(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  // Pop back twice to get out of the exercise flow completely
                  Navigator.pop(context); // pop summary
                  Navigator.pop(context); // pop details
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Finish',
                  style: GoogleFonts.readexPro(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.readexPro(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.readexPro(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
