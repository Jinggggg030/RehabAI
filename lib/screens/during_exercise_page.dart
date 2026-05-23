import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'exercise_summary_page.dart';

class DuringExercisePage extends StatelessWidget {
  const DuringExercisePage({super.key});

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
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Exercise Name',
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
                      // Camera Placeholder
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: 400,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade700,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Mjpeg(
                                    isLive: true,
                                    fit: BoxFit.cover,
                                    error: (context, error, stack) {
                                      return Center(
                                        child: Text(
                                          'Error loading stream',
                                          style: GoogleFonts.readexPro(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                    stream: 'http://10.0.2.2:8000/video_feed',
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: Row(
                                  children: [
                                    _buildControlButton(Icons.pause, () {}),
                                    const SizedBox(width: 8),
                                    _buildControlButton(Icons.stop, () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('End Session Early?', style: GoogleFonts.readexPro(fontWeight: FontWeight.bold)),
                                          content: Text('Are you sure you want to stop this exercise?', style: GoogleFonts.readexPro()),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text('Cancel', style: GoogleFonts.readexPro(color: Colors.grey.shade700)),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context); // close dialog
                                                Navigator.pop(context); // go back to details
                                              },
                                              child: Text('Stop', style: GoogleFonts.readexPro(color: Colors.red, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Progress Section
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Accuracy',
                              style: GoogleFonts.readexPro(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Accuracy Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: const LinearProgressIndicator(
                                value: 0.4, // 40% accuracy for example
                                minHeight: 16,
                                backgroundColor: Color(0xFFEEEEEE),
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Completed duration
                            _buildProgressLabel('Completed duration:', '[completed] / [duration]'),
                            const SizedBox(height: 4),
                            _buildProgressBar(0.0), // 0%

                            const SizedBox(height: 16),
                            
                            // Completed sets
                            _buildProgressLabel('Completed sets:', '[completed] / [total sets]'),
                            const SizedBox(height: 4),
                            _buildProgressBar(0.0), // 0%

                            const SizedBox(height: 32),
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ExerciseSummaryPage(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF207866),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'FINISH EXERCISE',
                                  style: GoogleFonts.readexPro(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
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

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black54, width: 2),
        ),
        child: Icon(icon, color: Colors.black54, size: 24),
      ),
    );
  }

  Widget _buildProgressLabel(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$title ',
                style: GoogleFonts.readexPro(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 12,
                ),
              ),
              TextSpan(
                text: value,
                style: GoogleFonts.readexPro(
                  fontWeight: FontWeight.normal,
                  color: Colors.black87,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double value) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Positioned(
          left: 0,
          top: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF207866),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
