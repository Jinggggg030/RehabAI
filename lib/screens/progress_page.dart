import 'package:rehab_ai/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/screens/live_chat_page.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40), // Spacer to balance center title
                  Text(
                    'Progress',
                    style: GoogleFonts.readexPro(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF207866),
                    ),
                  ),
                  const NotificationBell(),
                ],
              ),
              const SizedBox(height: 32),

              // Session Info
              Text(
                'Session: [Session Name With Injury]',
                textAlign: TextAlign.center,
                style: GoogleFonts.readexPro(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Physiotherapist: [Name]',
                textAlign: TextAlign.center,
                style: GoogleFonts.readexPro(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // 2x2 Stats Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4, // Adjust for width vs height
                children: [
                  _buildStatCard(
                    'Total Exercises',
                    const Color(0xFFE0F7FA), // Light Cyan
                  ),
                  _buildStatCard(
                    'Total Minutes',
                    const Color(0xFFE8EAF6), // Light Lavender
                  ),
                  _buildStatCard(
                    'Accuracy\nPercentage',
                    const Color(0xFFFFF9C4), // Light Yellow/Orange
                  ),
                  _buildStatCard(
                    'Average Pain\nLevel (?)',
                    const Color(0xFFDCEDC8), // Light Green
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Graph Placeholder
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Recovery Progress Graph',
                    style: GoogleFonts.readexPro(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, Color bgColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.readexPro(
              fontSize: 14,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
