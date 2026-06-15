import 'package:rehab_ai/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/screens/live_chat_page.dart';
import 'package:rehab_ai/screens/my_appointments_page.dart';
import 'package:rehab_ai/screens/rehabilitation_exercises_page.dart';
import 'package:rehab_ai/screens/equipment_rental_page.dart';
import 'package:rehab_ai/screens/contact_us_page.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Match HomePage background
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
                  // Empty placeholder to balance the center title with the trailing icon
                  const SizedBox(width: 48),
                  Text(
                    'Services',
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

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: GoogleFonts.readexPro(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                    suffixIcon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Service Cards List
              _buildServiceCard(
                'Live Chat',
                'description',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LiveChatPage()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildServiceCard(
                'Rehabilitation Exercises',
                'description',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RehabilitationExercisesPage()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildServiceCard(
                'Appointments',
                'description',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MyAppointmentsPage()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildServiceCard(
                'Equipment Rental',
                'description',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EquipmentRentalPage()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildServiceCard(
                'Contact',
                'description',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ContactUsPage()),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(String title, String description, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Image Placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8), // Slight rounding for the inner image box
            ),
          ),
          const SizedBox(width: 16),
          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.readexPro(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.readexPro(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
