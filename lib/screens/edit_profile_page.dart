import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  String _gender = 'Male';
  String _hostel = 'Yes';
  bool _isLoading = true;
  bool _isSaving = false;
  String _supabaseId = '';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _matricController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _icController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _address3Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    _supabaseId = user.id;
    final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();

    try {
      final res = await http.get(Uri.parse('$apiUrl/users/profile/$_supabaseId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['exists'] == true) {
          _nameController.text = data['username'] ?? '';
          _matricController.text = data['matric_no'] ?? '';
          _emailController.text = data['email'] ?? '';
          _icController.text = data['identity_number'] ?? '';
          
          if (data['gender'] != null) {
            _gender = data['gender'] == 'M' ? 'Male' : 'Female';
          }
          if (data['accommodation_type'] != null) {
            _hostel = data['accommodation_type'];
          }
          
          final ic = data['identity_number'] ?? '';
          if (ic.length >= 6) {
            _yearController.text = ic.substring(0, 2);
            _monthController.text = ic.substring(2, 4);
            _dayController.text = ic.substring(4, 6);
          }

          final fullAddress = data['address'] ?? '';
          final addressParts = fullAddress.split(', ');
          if (addressParts.isNotEmpty) _address1Controller.text = addressParts[0];
          if (addressParts.length > 1) _address2Controller.text = addressParts[1];
          if (addressParts.length > 2) _address3Controller.text = addressParts.skip(2).join(', ');
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_supabaseId.isEmpty) return;
    
    setState(() => _isSaving = true);
    
    final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    
    final addressList = [
      _address1Controller.text.trim(),
      _address2Controller.text.trim(),
      _address3Controller.text.trim(),
    ].where((e) => e.isNotEmpty).join(', ');

    final updateData = {
      "username": _nameController.text.trim(),
      "matric_no": _matricController.text.trim(),
      "email": _emailController.text.trim(),
      "identity_number": _icController.text.trim(),
      "gender": _gender == 'Male' ? 'M' : 'F',
      "accommodation_type": _hostel,
      "address": addressList,
    };

    try {
      final res = await http.put(
        Uri.parse('$apiUrl/users/profile/$_supabaseId'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(updateData),
      );
      
      if (mounted) {
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF207866)));
          Navigator.pop(context, true); // Return true to indicate change
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: ${res.body}'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _matricController.dispose();
    _emailController.dispose();
    _icController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _address3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF207866)))
        : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              SizedBox(
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
                        'Edit Profile',
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
              const SizedBox(height: 32),

              // Form Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 1),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLabel('Name'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _nameController, hintText: '[Name]'),
                    const SizedBox(height: 20),

                    _buildLabel('Matric Number'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _matricController, hintText: '[Matric Number]'),
                    const SizedBox(height: 20),

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
                    const SizedBox(height: 20),

                    _buildLabel('Email'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _emailController, hintText: '[Email address]'),
                    const SizedBox(height: 20),

                    _buildLabel('Identity Number'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _icController, hintText: '[I/C Number]'),
                    const SizedBox(height: 20),

                    _buildLabel('Birthdate'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _dayController,
                            hintText: 'DD',
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _monthController,
                            hintText: 'MM',
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _yearController,
                            hintText: 'YYYY',
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

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
                    const SizedBox(height: 20),

                    _buildLabel('Address Line 1'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _address1Controller, hintText: 'Address Line 1'),
                    const SizedBox(height: 20),

                    _buildLabel('Address Line 2'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _address2Controller, hintText: 'Address Line 2'),
                    const SizedBox(height: 20),

                    _buildLabel('Address Line 3'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _address3Controller, hintText: 'Address Line 3'),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF207866),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.readexPro(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ],
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
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textAlign: textAlign,
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
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
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
          SizedBox(
            width: 24,
            height: 24,
            child: Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: Colors.black87,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.readexPro(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
