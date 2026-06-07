import os

filepath = r"d:\UTeM\Y3S2\BITU3973 FYP\rehab_ai\lib\screens\physio_dashboard.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Add google_fonts import if not present
if "import 'package:google_fonts/google_fonts.dart';" not in content:
    content = content.replace("import 'package:flutter/foundation.dart' show kIsWeb;", "import 'package:flutter/foundation.dart' show kIsWeb;\nimport 'package:google_fonts/google_fonts.dart';")

new_method = """
  Future<void> _showApplyLeaveDialog() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue.shade800),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator())
    );

    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/physiotherapists/colleagues/${widget.myUserId}'));
      
      if (!mounted) return;
      Navigator.pop(context); // Pop loading

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final colleagues = data['colleagues'] as List<dynamic>? ?? [];
        
        if (colleagues.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No colleagues available to cover.")));
          }
          return;
        }

        int? selectedColleagueId = colleagues.first['therapist_id'];

        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return StatefulBuilder(builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text("Apply Emergency Leave"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Leave Period: ${picked.start.toLocal().toString().split(' ')[0]} to ${picked.end.toLocal().toString().split(' ')[0]}"),
                      const SizedBox(height: 16),
                      const Text("Select a covering colleague:"),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: selectedColleagueId,
                        items: colleagues.map<DropdownMenuItem<int>>((c) {
                          return DropdownMenuItem<int>(
                            value: c['therapist_id'],
                            child: Text("${c['name']} (${c['specialization']})"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedColleagueId = val;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedColleagueId == null) return;
                        try {
                          final leaveRes = await http.put(
                            Uri.parse('$apiUrl/physio/leave/${widget.myUserId}'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                                "start_date": picked.start.toUtc().toIso8601String(),
                                "end_date": picked.end.toUtc().toIso8601String(),
                                "cover_colleague_id": selectedColleagueId
                            }),
                          );
                          if (leaveRes.statusCode == 200) {
                            if (mounted) Navigator.pop(dialogContext);
                            _fetchAppointments();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leave applied & appointments transferred!")));
                            }
                          }
                        } catch (e) {
                          debugPrint("Leave error: $e");
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
                      child: const Text("Confirm Leave"),
                    ),
                  ],
                );
              });
            }
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Appointments", style: GoogleFonts.readexPro(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
              ElevatedButton.icon(
                onPressed: _showApplyLeaveDialog,
                icon: const Icon(Icons.time_to_leave, size: 18),
                label: const Text("Apply Leave"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade900, elevation: 0, side: BorderSide(color: Colors.red.shade200)),
              )
            ],
          ),
          const SizedBox(height: 24),
          if (_appointments.isEmpty)
             const Expanded(child: Center(child: Text("No appointments scheduled.")))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _appointments.length,
                itemBuilder: (context, index) {
                  final a = _appointments[index];
                  final date = DateTime.tryParse(a['schedule_time'] ?? '')?.toLocal().toString().split('.')[0] ?? 'Unknown';
                  final isScheduled = a['status'] == 'Scheduled';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.person, color: Colors.blue),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['student_name'] ?? 'Unknown', style: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(date, style: GoogleFonts.readexPro(fontSize: 14, color: Colors.grey.shade700)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Chip(
                                label: Text(a['status'] ?? '', style: TextStyle(color: isScheduled ? Colors.blue.shade900 : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                                backgroundColor: isScheduled ? Colors.blue.shade50 : Colors.grey.shade200,
                                side: BorderSide.none,
                              ),
                              if (isScheduled) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _showTransferDialog(a),
                                  icon: const Icon(Icons.swap_horiz, size: 16),
                                  label: const Text("Transfer"),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800, side: BorderSide(color: Colors.orange.shade200)),
                                )
                              ]
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
"""

# Replace the old build method to the end of the class
old_build_start = "  @override\n  Widget build(BuildContext context) {"
if old_build_start in content:
    start_idx = content.find(old_build_start)
    end_idx = content.find("}\n\n// ---------------------------------------------------------------------------", start_idx)
    
    if end_idx != -1:
        # replace
        content = content[:start_idx] + new_method + content[end_idx+1:]
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Patched successfully!")
    else:
        print("Could not find end of class")
else:
    print("Could not find old build method")

