import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rehab_ai/screens/login_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _supabase = Supabase.instance.client;
  int? _myUserId;
  int _selectedIndex = 0;
  
  List<dynamic> _rentals = [];
  List<dynamic> _equipment = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }
  
  Future<void> _initDashboard() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    final userRes = await http.get(Uri.parse('$apiUrl/users/profile/${user.id}'));
    
    if (userRes.statusCode == 200) {
      final userData = jsonDecode(userRes.body);
      if (userData['exists'] == true) {
        setState(() {
          _myUserId = userData['user_id'];
        });
        _fetchRentals();
        _fetchEquipment();
      }
    }
  }

  Future<void> _fetchRentals() async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/admin/rentals'));
      if (res.statusCode == 200) {
        setState(() {
          _rentals = jsonDecode(res.body)['rentals'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching rentals: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEquipment() async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/equipment'));
      if (res.statusCode == 200) {
        setState(() {
          _equipment = jsonDecode(res.body)['equipment'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching equipment: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRentalStatus(int rentalId, String newStatus, {String? returnStatus}) async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final body = {
        'status': newStatus,
        'admin_id': _myUserId,
      };
      if (returnStatus != null) {
        body['return_status'] = returnStatus;
      }
      final res = await http.put(
        Uri.parse('$apiUrl/admin/rentals/$rentalId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body)
      );
      if (res.statusCode == 200) {
        _fetchRentals();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated successfully'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showReturnDialog(int rentalId) {
    String selectedReturnStatus = 'Good';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Mark as Returned', style: GoogleFonts.readexPro()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Equipment Condition:', style: GoogleFonts.readexPro(fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedReturnStatus,
                    isExpanded: true,
                    items: ['Good', 'Damaged', 'Lost'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedReturnStatus = v!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.readexPro(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateRentalStatus(rentalId, 'Returned', returnStatus: selectedReturnStatus);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF207866)),
                  child: Text('Confirm', style: GoogleFonts.readexPro(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildRentalRequests() {
    final pending = _rentals.where((r) => r['status'] == 'Pending').toList();
    if (_isLoading && pending.isEmpty) return const Center(child: CircularProgressIndicator());
    if (pending.isEmpty) return Center(child: Text("No pending rental requests.", style: GoogleFonts.readexPro()));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final r = pending[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Student: ${r['student_name']}", style: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Equipment: ${r['equipment_name']}", style: GoogleFonts.readexPro(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 4),
                Text("Reason: ${r['custom_reason'] ?? r['rental_reason']}", style: GoogleFonts.readexPro(fontSize: 14, color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Text("Duration: ${r['rental_duration']} days", style: GoogleFonts.readexPro(fontSize: 14, color: Colors.grey.shade700)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _updateRentalStatus(r['rental_record_id'], 'Rejected'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _updateRentalStatus(r['rental_record_id'], 'Approved'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF207866), foregroundColor: Colors.white),
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveRentals() {
    final active = _rentals.where((r) => r['status'] == 'Approved' || r['status'] == 'Active').toList();
    if (_isLoading && active.isEmpty) return const Center(child: CircularProgressIndicator());
    if (active.isEmpty) return Center(child: Text("No active rentals.", style: GoogleFonts.readexPro()));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final r = active[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Student: ${r['student_name']}", style: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: r['status'] == 'Approved' ? Colors.orange.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(r['status'], style: GoogleFonts.readexPro(fontSize: 12, color: r['status'] == 'Approved' ? Colors.orange.shade800 : Colors.green.shade800, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text("Equipment: ${r['equipment_name']}", style: GoogleFonts.readexPro(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 4),
                Text("Collection: ${r['collection_date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(r['collection_date'])) : 'Unknown'}", style: GoogleFonts.readexPro(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (r['status'] == 'Approved')
                      ElevatedButton(
                        onPressed: () => _updateRentalStatus(r['rental_record_id'], 'Active'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF207866), foregroundColor: Colors.white),
                        child: const Text('Mark Collected'),
                      ),
                    if (r['status'] == 'Active')
                      ElevatedButton(
                        onPressed: () => _showReturnDialog(r['rental_record_id']),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                        child: const Text('Mark Returned'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEquipmentDialog([Map<String, dynamic>? eq]) {
    final nameController = TextEditingController(text: eq?['name'] ?? '');
    final descController = TextEditingController(text: eq?['description'] ?? '');
    final stockController = TextEditingController(text: (eq?['stock'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(eq == null ? 'Add Equipment' : 'Edit Equipment', style: GoogleFonts.readexPro(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: 'Stock'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
                  final body = jsonEncode({
                    'name': nameController.text,
                    'description': descController.text,
                    'stock': int.tryParse(stockController.text) ?? 0,
                    'admin_id': _myUserId,
                  });
                  http.Response res;
                  if (eq == null) {
                    res = await http.post(Uri.parse('$apiUrl/admin/equipment'), headers: {'Content-Type': 'application/json'}, body: body);
                  } else {
                    res = await http.put(Uri.parse('$apiUrl/admin/equipment/${eq['equipment_id']}'), headers: {'Content-Type': 'application/json'}, body: body);
                  }
                  if (res.statusCode == 200) {
                    _fetchEquipment();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  debugPrint("Error saving equipment: $e");
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF207866), foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        );
      }
    );
  }

  Future<void> _deleteEquipment(int id) async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.delete(Uri.parse('$apiUrl/admin/equipment/$id'));
      if (res.statusCode == 200) {
        _fetchEquipment();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Error deleting equipment: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildInventory() {
    if (_isLoading && _equipment.isEmpty) return const Center(child: CircularProgressIndicator());
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
          itemCount: _equipment.length,
          itemBuilder: (context, index) {
            final eq = _equipment[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(eq['name'], style: GoogleFonts.readexPro(fontWeight: FontWeight.bold)),
                subtitle: Text("Stock: ${eq['stock']}\n${eq['description'] ?? ''}", style: GoogleFonts.readexPro(fontSize: 12, color: Colors.grey.shade600)),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEquipmentDialog(eq),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Equipment?'),
                            content: const Text('Are you sure you want to delete this equipment?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                              TextButton(onPressed: () {
                                Navigator.pop(c);
                                _deleteEquipment(eq['equipment_id']);
                              }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ]
                          )
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: () => _showEquipmentDialog(),
            backgroundColor: const Color(0xFF207866),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Admin Portal', style: GoogleFonts.readexPro(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1B3C35),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            minWidth: 130,
            selectedIconTheme: const IconThemeData(color: Color(0xFF207866)),
            unselectedIconTheme: const IconThemeData(color: Colors.black54),
            selectedLabelTextStyle: GoogleFonts.readexPro(color: const Color(0xFF207866), fontWeight: FontWeight.bold),
            unselectedLabelTextStyle: GoogleFonts.readexPro(color: Colors.black54, fontWeight: FontWeight.w500),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.assignment_late_outlined),
                selectedIcon: Icon(Icons.assignment_late),
                label: Text('Requests'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_turned_in_outlined),
                selectedIcon: Icon(Icons.assignment_turned_in),
                label: Text('Active Rentals'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Inventory'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _selectedIndex == 0
                ? _buildRentalRequests()
                : _selectedIndex == 1
                    ? _buildActiveRentals()
                    : _buildInventory(),
          ),
        ],
      ),
    );
  }
}
