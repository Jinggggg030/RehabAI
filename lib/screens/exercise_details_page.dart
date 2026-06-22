import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'during_exercise_page.dart';
import 'pose_camera_page.dart';
import 'rep_counter_page.dart';
import '../utils/exercise_formatters.dart';

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
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _videoLoadFailed = false;

  String get _aiType =>
      (widget.exercise['ai_type'] ?? '').toString().trim().toLowerCase();

  bool get _usesAi => widget.exercise['requires_ai'] == true;

  Map<String, dynamic> get _exerciseForSession => {
    ...widget.exercise,
    'session_origin': widget.isAssigned ? 'Assigned' : 'Self-selected',
  };

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final videoUrl = widget.exercise['video_url'];
    if (videoUrl != null && videoUrl.toString().trim().isNotEmpty) {
      try {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl.toString().trim()),
        );
        _videoPlayerController = controller;
        await controller.initialize();
        if (!mounted) {
          controller.dispose();
          return;
        }
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: false,
          looping: false,
          aspectRatio: controller.value.aspectRatio > 0
              ? controller.value.aspectRatio
              : 16 / 9,
          allowFullScreen: true,
          allowMuting: true,
          showControlsOnInitialize: true,
          placeholder: const ColoredBox(color: Colors.black),
          materialProgressColors: ChewieProgressColors(
            playedColor: const Color(0xFF1565C0),
            handleColor: const Color(0xFF1565C0),
            backgroundColor: Colors.grey.shade300,
            bufferedColor: Colors.grey.shade500,
          ),
        );
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint("Error initializing video player: $e");
        if (mounted) setState(() => _videoLoadFailed = true);
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  double get _displayVideoAspectRatio {
    final controller = _videoPlayerController;
    if (controller != null && controller.value.isInitialized) {
      final ratio = controller.value.aspectRatio;
      if (ratio.isFinite && ratio > 0) return ratio;
    }
    return 16 / 9;
  }

  Widget _buildVideoPlaceholder() {
    final videoUrl = widget.exercise['video_url']?.toString().trim() ?? '';
    if (videoUrl.isEmpty) {
      return Center(
        child: Text(
          'No demonstration video available',
          style: GoogleFonts.readexPro(color: Colors.white70),
        ),
      );
    }
    if (_videoLoadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_file_outlined,
              color: Colors.white54,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load this video',
              style: GoogleFonts.readexPro(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF1565C0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
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
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.exercise['name'] ?? 'Exercise Details',
                      style: GoogleFonts.readexPro(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1565C0),
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
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: AspectRatio(
                            aspectRatio: _displayVideoAspectRatio,
                            child:
                                _chewieController != null &&
                                    _videoPlayerController!.value.isInitialized
                                ? Chewie(controller: _chewieController!)
                                : _buildVideoPlaceholder(),
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
                              'Discipline: ${exerciseDisciplineLabel(widget.exercise)}',
                              style: GoogleFonts.readexPro(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1565C0),
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
                              widget.exercise['description'] ??
                                  'No description available.',
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
                                        exercise: _exerciseForSession,
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
                                        exercise: _exerciseForSession,
                                        scheduleId: widget.scheduleId,
                                      ),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DuringExercisePage(
                                        exercise: _exerciseForSession,
                                        scheduleId: widget.scheduleId,
                                      ),
                                    ),
                                  );
                                }
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
                                _usesAi
                                    ? 'Start Live AI Tracking'
                                    : 'Start Exercise',
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
