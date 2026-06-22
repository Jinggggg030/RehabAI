import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    Text(
                      'Terms and Conditions',
                      style: GoogleFonts.readexPro(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(width: 40), // Empty placeholder to balance the row
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('1. Acceptance of Terms'),
                    _buildSectionBody(
                      'By downloading, accessing, or using Rehab AI ("the App"), you agree to be bound by these Terms and Conditions. If you do not agree, do not use the App.',
                    ),
                    _buildSectionTitle('2. Medical Disclaimer'),
                    _buildSectionBody(
                      'Rehab AI is designed to assist with physiotherapy exercises and recovery tracking. However, it is NOT a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or qualified health provider with any questions you may have regarding a medical condition.',
                    ),
                    _buildSectionTitle('3. AI Analysis & Camera Usage'),
                    _buildSectionBody(
                      'The App utilizes your device\'s camera to provide real-time AI feedback on your form during exercises. By using this feature, you consent to the processing of your motion data. We do not permanently store or share live video feeds with third parties without your explicit consent.',
                    ),
                    _buildSectionTitle('4. User Responsibilities'),
                    _buildSectionBody(
                      'You are solely responsible for ensuring that you perform the exercises in a safe environment. Do not push through severe pain. If you experience unexpected discomfort, stop immediately and consult your assigned physiotherapist.',
                    ),
                    _buildSectionTitle('5. Data Privacy'),
                    _buildSectionBody(
                      'Your personal health data, exercise progress, and chat logs are strictly confidential and encrypted. They will only be shared with your designated physiotherapist within the Rehab AI platform.',
                    ),
                    _buildSectionTitle('6. Limitation of Liability'),
                    _buildSectionBody(
                      'Rehab AI and its creators shall not be held liable for any injuries, damages, or complications arising from the misuse of the App or from following the provided exercise routines incorrectly.',
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        'Last Updated: June 2026',
                        style: GoogleFonts.readexPro(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.readexPro(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSectionBody(String body) {
    return Text(
      body,
      style: GoogleFonts.readexPro(
        fontSize: 14,
        color: Colors.black87,
        height: 1.6,
      ),
    );
  }
}
