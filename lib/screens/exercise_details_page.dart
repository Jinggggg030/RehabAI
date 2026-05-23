import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'during_exercise_page.dart';

class ExerciseDetailsPage extends StatelessWidget {
  final bool isAssigned;
  const ExerciseDetailsPage({super.key, required this.isAssigned});

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
                      // Video Placeholder
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade700,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '[exercise preview video]',
                              style: GoogleFonts.readexPro(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Information section
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: isAssigned 
                            ? [
                                _buildInfoRow('Injury part:', '[part]'),
                                const SizedBox(height: 12),
                                _buildInfoRow('Assigned date:', '[date]'),
                                const SizedBox(height: 12),
                                _buildInfoRow('Total sets:', '[sets]'),
                                const SizedBox(height: 12),
                                _buildInfoRow('Duration per set:', '[duration]'),
                                const SizedBox(height: 12),
                                _buildInfoRow('Precautions:', '[description]'),
                              ]
                            : [
                                _buildInfoRow('Target Muscle:', '[muscle group]'),
                                const SizedBox(height: 12),
                                _buildInfoRow('Difficulty:', '[level]'),
                                const SizedBox(height: 12),
                                _buildInfoRow('Equipment needed:', '[equipment]'),
                                const SizedBox(height: 12),
                                _buildInfoRow('Instructions:', '[general steps]'),
                              ],
                        ),
                      ),

                      // Start Button
                      Padding(
                        padding: const EdgeInsets.only(left: 48.0, right: 48.0, bottom: 24.0, top: 12.0),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DuringExercisePage(),
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
                            elevation: 0,
                          ),
                          child: Text(
                            isAssigned ? 'START' : 'Try it out',
                            style: GoogleFonts.readexPro(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
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

  Widget _buildInfoRow(String title, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$title ',
            style: GoogleFonts.readexPro(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          TextSpan(
            text: value,
            style: GoogleFonts.readexPro(
              fontWeight: FontWeight.normal,
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
