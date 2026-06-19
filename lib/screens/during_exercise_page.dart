import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:async';
import 'session_summary_page.dart';

class DuringExercisePage extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final int? scheduleId;

  const DuringExercisePage({
    super.key,
    required this.exercise,
    this.scheduleId,
  });

  @override
  State<DuringExercisePage> createState() => _DuringExercisePageState();
}

class _DuringExercisePageState extends State<DuringExercisePage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  bool _isSessionStarted = false;
  Timer? _timer;
  int _totalDuration = 300; // Default 5 minutes
  int _secondsRemaining = 300;
  int _secondsElapsed = 0;
  int _completedReps = 0;
  bool _trackByTime = true;

  int? _painBefore;
  int? _painAfter;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    // Prompt for Pain Before when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPainDialog(isBefore: true);
    });
  }

  Future<void> _initializePlayer() async {
    final videoUrl = widget.exercise['video_url'];
    if (videoUrl != null && videoUrl.isNotEmpty) {
      try {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        await _videoPlayerController.initialize();
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: false,
          looping: true,
          aspectRatio: _videoPlayerController.value.aspectRatio,
          materialProgressColors: ChewieProgressColors(
            playedColor: const Color(0xFF207866),
            handleColor: const Color(0xFF207866),
            backgroundColor: Colors.grey.shade300,
            bufferedColor: Colors.grey.shade500,
          ),
        );
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint("Error initializing video player: $e");
      }
    }
  }

  void _startSession() {
    setState(() {
      _isSessionStarted = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_trackByTime) {
            if (_secondsRemaining > 0) {
              _secondsRemaining--;
            } else {
              _timer?.cancel();
              _onCompleteSessionTapped();
            }
          } else {
            _secondsElapsed++;
          }
        });
      }
    });
  }

  void _showPainDialog({required bool isBefore}) {
    int localPain = 0;
    int localDurationMinutes = 5; // Default 5 minutes
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isBefore ? 'Exercise Setup' : 'Session Complete'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isBefore ? 'Rate your Pain Before Exercise' : 'Rate your Pain After Exercise',
                      style: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '0 (No Pain) to 10 (Worst Pain)',
                      style: GoogleFonts.readexPro(fontSize: 12, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$localPain',
                      style: GoogleFonts.readexPro(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF207866)),
                    ),
                    Slider(
                      value: localPain.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      activeColor: const Color(0xFF207866),
                      onChanged: (value) {
                        setDialogState(() {
                          localPain = value.toInt();
                        });
                      },
                    ),
                    
                    if (isBefore) ...[
                      const Divider(height: 32),
                      Text(
                        'How do you want to track this?',
                        style: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Timer'),
                            selected: _trackByTime,
                            onSelected: (selected) {
                              setDialogState(() {
                                _trackByTime = true;
                              });
                            },
                            selectedColor: const Color(0xFF207866).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: _trackByTime ? const Color(0xFF207866) : Colors.black87,
                              fontWeight: _trackByTime ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ChoiceChip(
                            label: const Text('Reps'),
                            selected: !_trackByTime,
                            onSelected: (selected) {
                              setDialogState(() {
                                _trackByTime = false;
                              });
                            },
                            selectedColor: const Color(0xFF207866).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: !_trackByTime ? const Color(0xFF207866) : Colors.black87,
                              fontWeight: !_trackByTime ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (_trackByTime) ...[
                        Text(
                          'Set Timer Duration',
                          style: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 32,
                            color: Colors.red,
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (localDurationMinutes > 1) {
                                setDialogState(() {
                                  localDurationMinutes--;
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '$localDurationMinutes min',
                            style: GoogleFonts.readexPro(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            iconSize: 32,
                            color: const Color(0xFF207866),
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              if (localDurationMinutes < 60) {
                                setDialogState(() {
                                  localDurationMinutes++;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ], // Closes if (_trackByTime)
                    ], // Closes if (isBefore)
                  ], // Closes Column children
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (isBefore) {
                        _painBefore = localPain;
                        if (_trackByTime) {
                          _totalDuration = localDurationMinutes * 60;
                          _secondsRemaining = localDurationMinutes * 60;
                        } else {
                          _secondsElapsed = 0;
                        }
                      } else {
                        _painAfter = localPain;
                      }
                    });
                    Navigator.pop(context);
                    if (isBefore) {
                      _startSession();
                    } else {
                      _completeSessionNavigation();
                    }
                  },
                  child: Text('Confirm', style: GoogleFonts.readexPro(fontWeight: FontWeight.bold, color: const Color(0xFF207866))),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _onCompleteSessionTapped() {
    _timer?.cancel();
    _showPainDialog(isBefore: false);
  }

  void _completeSessionNavigation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SessionSummaryPage(
          exerciseName: widget.exercise['name'] ?? 'Video Exercise',
          durationSeconds: _trackByTime ? (_totalDuration - _secondsRemaining) : _secondsElapsed,
          reps: _completedReps,
          accuracyScore: null, // No AI score for manual tracking
          painBefore: _painBefore,
          painAfter: _painAfter,
          exerciseId: widget.exercise['exercise_id'] ?? 1,
          scheduleId: widget.scheduleId,
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_chewieController != null) {
      _videoPlayerController.dispose();
      _chewieController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _timer?.cancel();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.exercise['name'] ?? 'Exercise',
                      style: GoogleFonts.readexPro(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF207866),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Video Player
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                              ? Chewie(controller: _chewieController!)
                              : Center(
                                  child: widget.exercise['video_url'] == null 
                                  ? Text('No video available', style: GoogleFonts.readexPro(color: Colors.white))
                                  : const CircularProgressIndicator(color: Color(0xFF207866)),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Metrics
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricColumn(
                            _trackByTime ? "Time Left" : "Time", 
                            _formatTime(_trackByTime ? _secondsRemaining : _secondsElapsed)
                          ),
                          _buildMetricColumn("Pain Before", _painBefore != null ? '$_painBefore/10' : '-'),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Manual Rep Counter
                      if (!_trackByTime) ...[
                        Text(
                          'Completed Reps',
                          style: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 48,
                              color: Colors.red,
                              icon: const Icon(Icons.remove_circle),
                              onPressed: () {
                                if (_completedReps > 0) {
                                  setState(() => _completedReps--);
                                }
                              },
                            ),
                            const SizedBox(width: 32),
                            Text(
                              '$_completedReps',
                              style: GoogleFonts.readexPro(fontSize: 48, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 32),
                            IconButton(
                              iconSize: 48,
                              color: const Color(0xFF207866),
                              icon: const Icon(Icons.add_circle),
                              onPressed: () {
                                setState(() => _completedReps++);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Complete Button
                      ElevatedButton(
                        onPressed: _isSessionStarted ? _onCompleteSessionTapped : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF207866),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Complete Session',
                          style: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.readexPro(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.readexPro(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }
}
