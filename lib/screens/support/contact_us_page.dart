import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.rehabBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
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
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Text(
                    'Contact Us',
                    style: GoogleFonts.readexPro(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(
                    width: 40,
                  ), // Empty placeholder to balance header
                ],
              ),
              const SizedBox(height: 40),

              // UTeM Healthcare Center Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD34F70), // Pink accent line
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Pusat Kesihatan UTeM',
                          style: GoogleFonts.readexPro(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.home_outlined,
                          color: Color(0xFFD34F70),
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Universiti Teknikal Malaysia Melaka,\nJalan Hang Tuah Jaya,\n76100 Durian Tunggal,\nMelaka.',
                            style: GoogleFonts.readexPro(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Phone Number
                    GestureDetector(
                      onTap: () => _launchUrl('tel:062292308'),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            color: Color(0xFFD34F70),
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '06-2292308',
                            style: GoogleFonts.readexPro(
                              fontSize: 14,
                              color: Colors.black54,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email Address
                    GestureDetector(
                      onTap: () =>
                          _launchUrl('mailto:pusatkesihatanutem@utem.edu.my'),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            color: Color(0xFFD34F70),
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Text(
                              'pusatkesihatanutem@utem.edu.my',
                              style: GoogleFonts.readexPro(
                                fontSize: 14,
                                color: Colors.black54,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Social Media Section (Placeholder for Contact Us image from screenshot)
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialIcon(Icons.facebook),
                    const SizedBox(width: 16),
                    _buildSocialIcon(
                      Icons.camera_alt_outlined,
                    ), // Instagram placeholder
                    const SizedBox(width: 16),
                    _buildSocialIcon(Icons.music_note), // Tiktok placeholder
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.black54, size: 20),
    );
  }
}
