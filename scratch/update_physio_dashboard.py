import os

with open('lib/screens/physio_dashboard.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = """  Future<void> _showTransferDialog(dynamic appointment) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      }
    );

    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/physiotherapists/colleagues/${widget.myUserId}'));
      
      Navigator.pop(context); // Pop loading dialog

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final colleagues = data['colleagues'] as List<dynamic>? ?? [];
        
        if (colleagues.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No colleagues with the same specialization found.")));
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
                  title: const Text("Transfer Appointment"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Select a colleague to transfer this appointment to:"),
                      const SizedBox(height: 16),
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
                          final transRes = await http.put(
                            Uri.parse('$apiUrl/appointments/${appointment['appointment_id']}/transfer'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({"new_therapist_id": selectedColleagueId}),
                          );
                          if (transRes.statusCode == 200) {
                            Navigator.pop(dialogContext);
                            _fetchAppointments();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appointment transferred successfully!")));
                            }
                          }
                        } catch (e) {
                          debugPrint("Transfer error: $e");
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                      child: const Text("Confirm Transfer"),
                    ),
                  ],
                );
              });
            }
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Pop loading dialog on error
      debugPrint("Error fetching colleagues: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_appointments.isEmpty) return const Center(child: Text("No appointments scheduled."));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
        columns: const [
          DataColumn(label: Text('Patient')),
          DataColumn(label: Text('Schedule Time')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Evaluation')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _appointments.map((a) {
          final date = DateTime.tryParse(a['schedule_time'] ?? '')?.toLocal().toString().split('.')[0] ?? 'Unknown';
          return DataRow(cells: [
            DataCell(Text(a['student_name'] ?? 'Unknown')),
            DataCell(Text(date)),
            DataCell(Chip(label: Text(a['status'] ?? ''))),
            DataCell(Text(a['evaluation'] ?? 'N/A')),
            DataCell(
              a['status'] == 'Scheduled'
                  ? ElevatedButton(
                      onPressed: () => _showTransferDialog(a),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      child: const Text('Transfer', style: TextStyle(fontSize: 12)),
                    )
                  : const SizedBox.shrink(),
            ),
          ]);
        }).toList(),
      ),
    );
  }"""

start_idx = content.find("  @override\n  Widget build(BuildContext context) {")
end_idx = content.find("}\n\n// ---------------------------------------------------------------------------", start_idx) + 1

if start_idx != -1 and end_idx != -1:
    new_content = content[:start_idx] + replacement + content[end_idx:]
    with open('lib/screens/physio_dashboard.dart', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Dashboard updated successfully!")
else:
    print("Could not find the target section")
