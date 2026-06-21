import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AiTrackingMode { duration, reps }

class AiSessionConfig {
  final AiTrackingMode mode;
  final int target;
  final int sets;
  final int painBefore;

  const AiSessionConfig({
    required this.mode,
    required this.target,
    required this.sets,
    required this.painBefore,
  });
}

Future<AiSessionConfig?> showAiSessionSetupDialog(
  BuildContext context, {
  required AiTrackingMode defaultMode,
  int? initialTarget,
  int? initialSets,
  bool prescribedSettings = false,
}) {
  var mode = defaultMode;
  var durationSeconds = mode == AiTrackingMode.duration
      ? (initialTarget ?? 30)
      : 30;
  var targetReps = mode == AiTrackingMode.reps ? (initialTarget ?? 10) : 10;
  var sets = initialSets ?? 3;
  var painBefore = 0;

  return showDialog<AiSessionConfig>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        void updateValue(String field, int delta) {
          setDialogState(() {
            if (field == 'duration') {
              durationSeconds = (durationSeconds + delta)
                  .clamp(15, 600)
                  .toInt();
            } else if (field == 'reps') {
              targetReps = (targetReps + delta).clamp(1, 100).toInt();
            } else {
              sets = (sets + delta).clamp(1, 10).toInt();
            }
          });
        }

        Widget stepper({
          required String label,
          required String value,
          required VoidCallback? decrease,
          required VoidCallback? increase,
        }) {
          return Column(
            children: [
              Text(
                label,
                style: GoogleFonts.readexPro(fontWeight: FontWeight.w600),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: decrease,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.readexPro(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: increase,
                    icon: const Icon(Icons.add_circle_outline),
                    color: const Color(0xFF207866),
                  ),
                ],
              ),
            ],
          );
        }

        return AlertDialog(
          title: const Text('AI Exercise Setup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tracking target per set',
                  style: GoogleFonts.readexPro(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                if (prescribedSettings) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF207866).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'These exercise targets were set by your physiotherapist.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SegmentedButton<AiTrackingMode>(
                  segments: const [
                    ButtonSegment(
                      value: AiTrackingMode.duration,
                      label: Text('Duration'),
                      icon: Icon(Icons.timer_outlined),
                    ),
                    ButtonSegment(
                      value: AiTrackingMode.reps,
                      label: Text('Reps'),
                      icon: Icon(Icons.repeat),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: prescribedSettings
                      ? null
                      : (selection) {
                          setDialogState(() => mode = selection.first);
                        },
                ),
                const SizedBox(height: 20),
                if (mode == AiTrackingMode.duration)
                  stepper(
                    label: 'Duration per set',
                    value: '$durationSeconds sec',
                    decrease: prescribedSettings
                        ? null
                        : () => updateValue('duration', -15),
                    increase: prescribedSettings
                        ? null
                        : () => updateValue('duration', 15),
                  )
                else
                  stepper(
                    label: 'Repetitions per set',
                    value: '$targetReps reps',
                    decrease: prescribedSettings
                        ? null
                        : () => updateValue('reps', -1),
                    increase: prescribedSettings
                        ? null
                        : () => updateValue('reps', 1),
                  ),
                const Divider(height: 28),
                stepper(
                  label: 'Number of sets',
                  value: '$sets sets',
                  decrease: prescribedSettings
                      ? null
                      : () => updateValue('sets', -1),
                  increase: prescribedSettings
                      ? null
                      : () => updateValue('sets', 1),
                ),
                const Divider(height: 28),
                Text(
                  'Pain before exercise: $painBefore/10',
                  style: GoogleFonts.readexPro(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: painBefore.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  activeColor: const Color(0xFF207866),
                  onChanged: (value) {
                    setDialogState(() => painBefore = value.round());
                  },
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  AiSessionConfig(
                    mode: mode,
                    target: mode == AiTrackingMode.duration
                        ? durationSeconds
                        : targetReps,
                    sets: sets,
                    painBefore: painBefore,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF207866),
              ),
              child: const Text('Continue to Camera'),
            ),
          ],
        );
      },
    ),
  );
}
