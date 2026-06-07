import os

with open('lib/screens/my_appointments_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add imports
imports = """import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
"""
content = content.replace("import 'package:flutter/material.dart';\nimport 'package:google_fonts/google_fonts.dart';", imports)

# We need to add state variables
state_vars = """  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  int? _myUserId;
  bool _isLoading = true;
  List<dynamic> _upcoming = [];
  List<dynamic> _past = [];
  List<dynamic> _cancelled = [];
  List<dynamic> _cancellationReasons = [];
  List<dynamic> _availablePhysios = [];"""
content = content.replace("  late TabController _tabController;", state_vars)

# InitState
init_state = """  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final userRes = await http.get(Uri.parse('$apiUrl/users/profile/${user.id}'));
      
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        if (userData['exists'] == true) {
          _myUserId = userData['user_id'];
          await _fetchAppointments();
          await _fetchCancellationReasons();
        }
      }
    } catch (e) {
      debugPrint("Init Data Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAppointments() async {
    if (_myUserId == null) return;
    final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    final res = await http.get(Uri.parse('$apiUrl/appointments/student/$_myUserId'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final all = data['appointments'] as List<dynamic>;
      final now = DateTime.now();
      
      setState(() {
        _cancelled = all.where((a) => a['status'] == 'Cancelled').toList();
        final notCancelled = all.where((a) => a['status'] != 'Cancelled').toList();
        
        _upcoming = notCancelled.where((a) {
          final time = DateTime.tryParse(a['schedule_time'] ?? '');
          return time != null && time.isAfter(now);
        }).toList();
        
        _past = notCancelled.where((a) {
          final time = DateTime.tryParse(a['schedule_time'] ?? '');
          return time != null && time.isBefore(now);
        }).toList();
      });
    }
  }

  Future<void> _fetchCancellationReasons() async {
    final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    final res = await http.get(Uri.parse('$apiUrl/appointments/cancellation_reasons'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        _cancellationReasons = data['reasons'] ?? [];
      });
    }
  }

  Future<void> _fetchAvailablePhysios() async {
    if (_myUserId == null) return;
    final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    final res = await http.get(Uri.parse('$apiUrl/appointments/available_physios/$_myUserId'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        _availablePhysios = data['physios'] ?? [];
      });
    }
  }"""
content = content.replace("""  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }""", init_state)


# Build Methods changes
content = content.replace("""Widget _buildAppointmentsList({bool isUpcoming = false, bool isPast = false, bool isCancelled = false}) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildAppointmentCard(isUpcoming: isUpcoming, isPast: isPast, isCancelled: isCancelled);
      },
    );
  }""", """Widget _buildAppointmentsList({bool isUpcoming = false, bool isPast = false, bool isCancelled = false}) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    List<dynamic> list = isUpcoming ? _upcoming : (isPast ? _past : _cancelled);
    
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No appointments found.',
          style: GoogleFonts.readexPro(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildAppointmentCard(list[index], isUpcoming: isUpcoming, isPast: isPast, isCancelled: isCancelled);
      },
    );
  }""")


# Card Widget
content = content.replace("""Widget _buildAppointmentCard({bool isUpcoming = false, bool isPast = false, bool isCancelled = false}) {""", """Widget _buildAppointmentCard(dynamic appointment, {bool isUpcoming = false, bool isPast = false, bool isCancelled = false}) {""")

content = content.replace("""onTap: isUpcoming ? () => _showAppointmentDialog(context) : null,""", """onTap: isUpcoming ? () => _showAppointmentDialog(context, appointment) : null,""")

content = content.replace("""'Appointment For [Body Part]'""", """'Appointment with ${appointment['physiotherapist_name']}'""")
content = content.replace("""'[Day, Date]'""", """DateFormat('EEE, MMM d').format(DateTime.tryParse(appointment['schedule_time'] ?? '') ?? DateTime.now())""")
content = content.replace("""'[Time]'""", """DateFormat('hh:mm a').format(DateTime.tryParse(appointment['schedule_time'] ?? '') ?? DateTime.now())""")
content = content.replace("""'[Details]'""", """appointment['specialization'] ?? 'Physiotherapy'""")
content = content.replace("""'[Prescription]'""", """'N/A'""")
content = content.replace("""'[Review]'""", """appointment['evaluation'] ?? 'N/A'""")
content = content.replace("""'[Reasons]'""", """appointment['cancellation_reason'] ?? 'N/A'""")


# Update _showAppointmentDialog
content = content.replace("""void _showAppointmentDialog(BuildContext context) {""", """void _showAppointmentDialog(BuildContext context, dynamic appointment) {""")
content = content.replace("""'[Appointment]'""", """'Appointment Details'""")
content = content.replace("""_buildDialogDetailRow('Time', '[Time]')""", """_buildDialogDetailRow('Time', DateFormat('EEE, MMM d, hh:mm a').format(DateTime.tryParse(appointment['schedule_time'] ?? '') ?? DateTime.now()))""")
content = content.replace("""_buildDialogDetailRow('Details', '[Details]')""", """_buildDialogDetailRow('Details', appointment['specialization'] ?? 'Physiotherapy')""")

content = content.replace("""Navigator.pop(context); // Close the detail dialog
                      _showCancelReasonDialog(context); // Show cancel reason dialog""", """Navigator.pop(context); // Close the detail dialog
                      _showCancelReasonDialog(context, appointment); // Show cancel reason dialog""")

# Update Cancel Reason Dialog
content = content.replace("""void _showCancelReasonDialog(BuildContext context) {""", """
  int? _selectedCancelReasonId;
  final TextEditingController _cancelOtherReasonCtrl = TextEditingController();

  void _showCancelReasonDialog(BuildContext context, dynamic appointment) {
    _selectedCancelReasonId = _cancellationReasons.isNotEmpty ? _cancellationReasons.first['reason_id'] : null;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setState) {""")

content = content.replace("""child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                            items: const [], // Empty for now, can be populated later
                            onChanged: (value) {},
                          ),
                        ),""", """child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedCancelReasonId,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                            items: _cancellationReasons.map<DropdownMenuItem<int>>((r) {
                              return DropdownMenuItem<int>(
                                value: r['reason_id'],
                                child: Text(r['description']),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCancelReasonId = val),
                          ),
                        ),""")

content = content.replace("""child: TextField(
                    maxLines: null,
                    decoration: InputDecoration(""", """child: TextField(
                    controller: _cancelOtherReasonCtrl,
                    maxLines: null,
                    decoration: InputDecoration(""")

content = content.replace("""Navigator.pop(context); // Close cancel dialog
                        _showAppointmentDialog(context); // Reopen the detail dialog""", """Navigator.pop(context);
                        _showAppointmentDialog(context, appointment);""")

content = content.replace("""Navigator.pop(context); // Close cancel dialog
                        // TODO: Implement actual cancellation logic here""", """
                        final reasonId = _selectedCancelReasonId;
                        if (reasonId != null) {
                          _cancelAppointment(appointment['appointment_id'], reasonId, _cancelOtherReasonCtrl.text);
                          Navigator.pop(context);
                        }""")

# Add cancel function
cancel_func = """
  Future<void> _cancelAppointment(int appointmentId, int reasonId, String otherReason) async {
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.put(
        Uri.parse('$apiUrl/appointments/$appointmentId/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"reason_id": reasonId, "other_reason": otherReason}),
      );
      if (res.statusCode == 200) {
        _fetchAppointments();
      }
    } catch (e) {
      debugPrint("Error cancelling appointment: $e");
    }
  }
"""
content = content.replace("""Widget _buildDialogDetailRow(String label, String value) {""", cancel_func + "\n" + """  Widget _buildDialogDetailRow(String label, String value) {""")


# Now handle the floating action button -> _showBookAppointmentBottomSheet
content = content.replace("""floatingActionButton: FloatingActionButton(
        onPressed: () {},""", """floatingActionButton: FloatingActionButton(
        onPressed: () => _showBookAppointmentBottomSheet(context),""")

book_sheet_code = """
  Future<void> _showBookAppointmentBottomSheet(BuildContext context) async {
    await _fetchAvailablePhysios();
    int? selectedPhysioId = _availablePhysios.isNotEmpty ? _availablePhysios.first['therapist_id'] : null;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Book Appointment", style: GoogleFonts.readexPro(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF207866))),
                const SizedBox(height: 24),
                
                Text("Select Physiotherapist", style: GoogleFonts.readexPro(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedPhysioId,
                      items: _availablePhysios.map<DropdownMenuItem<int>>((p) {
                        return DropdownMenuItem<int>(
                          value: p['therapist_id'],
                          child: Text("${p['name']} (${p['specialization']}) ${p['recommended'] ? '⭐' : ''}"),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedPhysioId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Date", style: GoogleFonts.readexPro(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                              if (d != null) setModalState(() => selectedDate = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                              child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Time", style: GoogleFonts.readexPro(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final t = await showTimePicker(context: context, initialTime: selectedTime);
                              if (t != null) setModalState(() => selectedTime = t);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                              child: Text(selectedTime.format(context)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedPhysioId == null) return;
                      final dt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                      try {
                        final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
                        final res = await http.post(
                          Uri.parse('$apiUrl/appointments/book'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({
                            "student_id": _myUserId,
                            "therapist_id": selectedPhysioId,
                            "schedule_time": dt.toIso8601String()
                          }),
                        );
                        if (res.statusCode == 200) {
                          Navigator.pop(context);
                          _fetchAppointments();
                        }
                      } catch (e) {
                        debugPrint("Error booking: $e");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF207866),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text("Book Appointment", style: GoogleFonts.readexPro(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        });
      }
    );
  }
"""

content = content.replace("  Widget _buildDialogDetailRow", book_sheet_code + "\n  Widget _buildDialogDetailRow")


# Make sure we close the StatefulBuilder for the cancel dialog
content = content.replace("""              ],
            ),
          ),
        );
      },
    );
  }""", """              ],
            ),
          ),
        );
        });
      },
    );
  }""")


with open('lib/screens/my_appointments_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Finished update")
