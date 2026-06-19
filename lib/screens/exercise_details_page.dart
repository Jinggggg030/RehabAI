import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'during_exercise_page.dart';
import 'pose_camera_page.dart';
import 'rep_counter_page.dart';

class ExerciseDetailsPage extends StatefulWidget {
  final bool isAssigned;
  final Map<String, dynamic> exercise;
  final int? scheduleId;
  
  const ExerciseDetailsPage({
    super.key, 
    required this.isAssigned,
    required this.exercise,
    this.scheduleId,
  });

  @override
  State<ExerciseDetailsPage> createState() => _ExerciseDetailsPageState();
}

class _ExerciseDetailsPageState extends State<ExerciseDetailsPage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  String get _aiType =>
      (widget.exercise['ai_type'] ?? '').toString().trim().toLowerCase();

  bool get _usesAi => widget.exercise['requires_ai'] == true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
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
          looping: false,
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
        // Fallback or handle error if needed
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                      widget.exercise['name'] ?? 'Exercise Details',
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Video Player
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _chewieController != null &&
                                    _chewieController!.videoPlayerController.value.isInitialized
                                ? Chewie(controller: _chewieController!)
                                : Center(
                                    child: widget.exercise['video_url'] == null 
                                    ? Text(
                                        'No video available',
                                        style: GoogleFonts.readexPro(color: Colors.white),
                                      )
                                    : const CircularProgressIndicator(color: Color(0xFF207866)),
                                  ),
                          ),
                        ),
                      ),
                      
                      // Information section
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Discipline: ${widget.exercise['discipline'] ?? 'General'}',
                              style: GoogleFonts.readexPro(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF207866),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Description & Instructions',
                              style: GoogleFonts.readexPro(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.exercise['description'] ?? 'No description available.',
                              style: GoogleFonts.readexPro(
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            // Button to start live exercise
                            ElevatedButton(
                              onPressed: () {
                                if (_usesAi && _aiType == 'posture') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PoseCameraPage(
                                        exercise: widget.exercise,
                                        scheduleId: widget.scheduleId,
                                      ),
                                    ),
                                  );
                                } else if (_usesAi &&
                                    (_aiType == 'rep_count' ||
                                        _aiType == 'rep_counter')) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RepCounterPage(
                                        exercise: widget.exercise,
                                        scheduleId: widget.scheduleId,
                                      ),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DuringExercisePage(
                                        exercise: widget.exercise,
                                        scheduleId: widget.scheduleId,
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF207866),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _usesAi ? 'Start Live AI Tracking' : 'Start Exercise',
                                style: GoogleFonts.readexPro(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
}
