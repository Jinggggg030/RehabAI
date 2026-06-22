import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/screens/main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProfileSetupPage extends StatefulWidget {
  final String name;
  final String email;

  const ProfileSetupPage({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _identityController = TextEditingController();
  final TextEditingController _matricController = TextEditingController();
  final TextEditingController _dobDayController = TextEditingController();
  final TextEditingController _dobMonthController = TextEditingController();
  final TextEditingController _dobYearController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _address3Controller = TextEditingController();

  String _gender = 'Male';
  String _hostel = 'Yes';
  bool _isLoading = false;

  @override
  void dispose() {
    _contactController.dispose();
    _identityController.dispose();
    _matricController.dispose();
    _dobDayController.dispose();
    _dobMonthController.dispose();
    _dobYearController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _address3Controller.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabaseId = Supabase.instance.client.auth.currentUser?.id;
      if (supabaseId == null) {
        throw Exception("User is not authenticated");
      }

      final address = [
        _address1Controller.text.trim(),
        _address2Controller.text.trim(),
        _address3Controller.text.trim(),
      ].where((e) => e.isNotEmpty).join(", ");

      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();

      final response = await http.post(
        Uri.parse('$apiUrl/users/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "supabase_id": supabaseId,
          "username": widget.name,
          "identity_number": _identityController.text.trim(),
          "email": widget.email,
          "gender": _gender,
          "contact_number": _contactController.text.trim(),
          "address": address,
          "accommodation_type": _hostel == 'Yes' ? 'Hostel' : 'Outside',
          "matric_no": _matricController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        
        // Show Success Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF4F6F9), // Light grayish-blue circle
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Color(0xFF1565C0),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'You\'re all set!',
                      style: GoogleFonts.readexPro(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome ${widget.name} to\nour family!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.readexPro(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'You\'ll be sent to home shortly!',
                      style: GoogleFonts.readexPro(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        // Navigate to MainScreen after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // Close dialog
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          }
        });

      } else {
        throw Exception("Failed to save profile: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'Setting up profile',
                textAlign: TextAlign.center,
                style: GoogleFonts.readexPro(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 40),

              // Contact Number
              _buildLabel('Contact Number'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _contactController,
                hintText: 'Enter your contact number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              // Identity Number
              _buildLabel('Identity Number'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _identityController,
                hintText: 'Enter your identity number',
                icon: Icons.person_outline,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  String cleanVal = val.replaceAll('-', '');
                  if (cleanVal.length >= 6) {
                    setState(() {
                      final yy = cleanVal.substring(0, 2);
                      final mm = cleanVal.substring(2, 4);
                      final dd = cleanVal.substring(4, 6);
                      
                      int year = int.tryParse(yy) ?? 0;
                      if (year > 30) {
                        _dobYearController.text = '19$yy';
                      } else {
                        _dobYearController.text = '20$yy';
                      }
                      _dobMonthController.text = mm;
                      _dobDayController.text = dd;
                    });
                  } else {
                    setState(() {
                      _dobYearController.text = '';
                      _dobMonthController.text = '';
                      _dobDayController.text = '';
                    });
                  }
                }
              ),
              const SizedBox(height: 24),

              // Matric Number
              _buildLabel('Matric Number'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _matricController,
                hintText: 'Enter your matric number (e.g. B032123456)',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 24),

              // Date of Birth
              _buildLabel('Date of Birth'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _dobDayController,
                      hintText: 'DD',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _dobMonthController,
                      hintText: 'MM',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _dobYearController,
                      hintText: 'YYYY',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Gender
              _buildLabel('Gender'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildRadioButton(
                    title: 'Male',
                    value: 'Male',
                    groupValue: _gender,
                    onChanged: (value) => setState(() => _gender = value!),
                  ),
                  const SizedBox(width: 24),
                  _buildRadioButton(
                    title: 'Female',
                    value: 'Female',
                    groupValue: _gender,
                    onChanged: (value) => setState(() => _gender = value!),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // UTeM Hostels
              _buildLabel('Are you staying in UTeM Hostels?'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildRadioButton(
                    title: 'Yes',
                    value: 'Yes',
                    groupValue: _hostel,
                    onChanged: (value) => setState(() => _hostel = value!),
                  ),
                  const SizedBox(width: 24),
                  _buildRadioButton(
                    title: 'No',
                    value: 'No',
                    groupValue: _hostel,
                    onChanged: (value) => setState(() => _hostel = value!),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Specific Hostel selection
              if (_hostel == 'Yes') ...[
                _buildLabel('Select Hostel'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: ['Lekir', 'Lekiu', 'Jebat', 'Kasturi', 'Al Jazari', 'Lestari Blok A', 'Lestari Blok B']
                      .map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _address1Controller.text = val;
                        _address2Controller.text = '76100 Durian Tunggal';
                        _address3Controller.text = 'Malacca';
                      });
                    }
                  },
                  hint: const Text('Select your hostel'),
                ),
                const SizedBox(height: 24),
              ],

              // Address Line 1
              _buildLabel('Address Line 1'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _address1Controller, 
                hintText: 'Address Line 1'
              ),
              const SizedBox(height: 24),

              // Address Line 2
              _buildLabel('Address Line 2'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _address2Controller, 
                hintText: 'Address Line 2'
              ),
              const SizedBox(height: 24),

              // Address Line 3
              _buildLabel('Address Line 3'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _address3Controller, 
                hintText: 'Address Line 3'
              ),
              const SizedBox(height: 48),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0), // Primary green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.readexPro(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.readexPro(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    TextEditingController? controller,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    TextAlign textAlign = TextAlign.start,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF), // Very light grey bg
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textAlign: textAlign,
        onChanged: onChanged,
        style: GoogleFonts.readexPro(
          fontSize: 14,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.readexPro(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          prefixIcon: icon != null
              ? Icon(icon, color: Colors.grey.shade400, size: 20)
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: icon != null ? 16 : 18,
          ),
        ),
      ),
    );
  }

  Widget _buildRadioButton({
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged,
            activeColor: const Color(0xFF1565C0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(
            title,
            style: GoogleFonts.readexPro(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
