import os

with open('lib/screens/my_appointments_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if "import 'package:table_calendar/table_calendar.dart';" not in content:
    content = content.replace("import 'package:intl/intl.dart';", "import 'package:intl/intl.dart';\nimport 'package:table_calendar/table_calendar.dart';")

# Extract the existing _showBookAppointmentBottomSheet
start_idx = content.find("Future<void> _showBookAppointmentBottomSheet")
end_idx = content.find("Widget _buildDialogDetailRow", start_idx)

new_bottom_sheet = """Future<void> _showBookAppointmentBottomSheet(BuildContext context) async {
    await _fetchAvailablePhysios();
    int? selectedPhysioId = _availablePhysios.isNotEmpty ? _availablePhysios.first['therapist_id'] : null;
    DateTime _focusedDay = DateTime.now();
    DateTime? _selectedDay = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, 
                left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Book Appointment", style: GoogleFonts.readexPro(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF207866))),
                  const SizedBox(height: 24),
                  
                  Text("Select Physiotherapist", style: GoogleFonts.readexPro(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (!(_availablePhysios.any((p) => p['recommended'] == true)))
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(child: Text("Not sure which specialist to choose? Head over to the Live Chat and our AI will recommend the perfect physiotherapist for your symptoms!", style: GoogleFonts.readexPro(fontSize: 12, color: Colors.blue.shade900))),
                        ],
                      ),
                    ),
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
                  
                  Text("Select Date", style: GoogleFonts.readexPro(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.now(),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        setModalState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: const Color(0xFF207866),
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: const Color(0xFF207866).withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text("Select Time", style: GoogleFonts.readexPro(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: selectedTime);
                      if (t != null) setModalState(() => selectedTime = t);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(selectedTime.format(context), style: GoogleFonts.readexPro(fontSize: 16)),
                          const Icon(Icons.access_time, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedPhysioId == null || _selectedDay == null) return;
                        final dt = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, selectedTime.hour, selectedTime.minute);
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
            ),
          );
        });
      }
    );
  }

  """

content = content[:start_idx] + new_bottom_sheet + content[end_idx:]

with open('lib/screens/my_appointments_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Replaced UI with TableCalendar")
