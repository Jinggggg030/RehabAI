import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  String _gender = 'Male';
  String _hostel = 'Yes';

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
                    _buildTextField(hintText: '[Name]'),
                    const SizedBox(height: 20),

                    _buildLabel('Matric Number'),
                    const SizedBox(height: 8),
                    _buildTextField(hintText: '[Matric Number]'),
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
                    _buildTextField(hintText: '[Email address]'),
                    const SizedBox(height: 20),

                    _buildLabel('Identity Number'),
                    const SizedBox(height: 8),
                    _buildTextField(hintText: '[I/C Number]'),
                    const SizedBox(height: 20),

                    _buildLabel('Birthdate'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            hintText: 'DD',
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            hintText: 'MM',
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
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
                    _buildTextField(hintText: 'Address Line 1'),
                    const SizedBox(height: 20),

                    _buildLabel('Address Line 2'),
                    const SizedBox(height: 8),
                    _buildTextField(hintText: 'Address Line 2'),
                    const SizedBox(height: 20),

                    _buildLabel('Address Line 3'),
                    const SizedBox(height: 8),
                    _buildTextField(hintText: 'Address Line 3'),
                    const SizedBox(height: 12),
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
