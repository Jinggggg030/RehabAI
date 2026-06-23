import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StudentProfileDialog extends StatefulWidget {
  final String studentId;

  const StudentProfileDialog({super.key, required this.studentId});

  @override
  State<StudentProfileDialog> createState() => _StudentProfileDialogState();
}

class _StudentProfileDialogState extends State<StudentProfileDialog> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  String? _resolvedProfilePictureUrl;

  String get _apiUrl => kIsWeb
      ? 'http://127.0.0.1:8000'
      : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/users/profile/${widget.studentId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['exists'] == true) {
          setState(() {
            _profileData = data;
          });
          await _resolveProfilePicture(data['profile_picture']?.toString());
        }
      }
    } catch (e) {
      debugPrint("Error fetching student profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resolveProfilePicture(String? storedValue) async {
    final value = storedValue?.trim() ?? '';
    if (value.isEmpty) return;
    try {
      final url = value.startsWith('http://') || value.startsWith('https://')
          ? value
          : Supabase.instance.client.storage
                .from('profile_picture')
                .getPublicUrl(value);
      if (mounted) setState(() => _resolvedProfilePictureUrl = url);
    } catch (error) {
      debugPrint('Unable to load profile picture: $error');
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          const Divider(color: Colors.black12, height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : _profileData == null
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'Student profile not found.',
                        style: GoogleFonts.readexPro(color: Colors.black54),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Student Profile',
                              style: GoogleFonts.readexPro(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.black54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: Colors.blue.shade50,
                            backgroundImage: _resolvedProfilePictureUrl != null
                                ? NetworkImage(_resolvedProfilePictureUrl!)
                                : null,
                            child: _resolvedProfilePictureUrl == null
                                ? Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.blue.shade300,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildInfoRow('Name', _profileData?['username'] ?? ''),
                        _buildInfoRow('Matric Number', _profileData?['matric_no'] ?? ''),
                        _buildInfoRow('Email', _profileData?['email'] ?? ''),
                        _buildInfoRow('Gender', _profileData?['gender'] ?? ''),
                        _buildInfoRow('Contact Number', _profileData?['contact_number'] ?? ''),
                        _buildInfoRow('Identity Number', _profileData?['identity_number'] ?? ''),
                        _buildInfoRow('Address', _profileData?['address'] ?? ''),
                      ],
                    ),
                  ),
      ),
    );
  }
}
