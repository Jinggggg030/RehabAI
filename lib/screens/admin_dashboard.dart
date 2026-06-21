import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rehab_ai/screens/login_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

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
  final ImagePicker _picker = ImagePicker();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initDashboard();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_myUserId != null) {
        _fetchRentals(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
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

  Future<void> _fetchRentals({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/admin/rentals'));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _rentals = jsonDecode(res.body)['rentals'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching rentals: $e");
    } finally {
      if (!silent && mounted) setState(() => _isLoading = false);
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

  Future<void> _updateRentalStatus(
    int rentalId,
    String newStatus, {
    String? returnStatus,
    String? proofOfCollection,
    String? proofOfStatus,
  }) async {
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
      if (proofOfCollection != null) {
        body['proof_of_collection'] = proofOfCollection;
      }
      if (proofOfStatus != null) {
        body['proof_of_status'] = proofOfStatus;
      }
      final res = await http.put(
        Uri.parse('$apiUrl/admin/rentals/$rentalId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body)
      );
      if (res.statusCode == 200) {
        _fetchRentals();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated successfully'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCollectionDialog(int rentalId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Proof of Collection', style: GoogleFonts.readexPro(fontWeight: FontWeight.bold)),
          content: Text('Please upload an image as proof of collection.', style: GoogleFonts.readexPro(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.readexPro(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text('Upload Photo', style: GoogleFonts.readexPro()),
              onPressed: () async {
                Navigator.pop(context);
                final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (pickedFile != null) {
                  _uploadProofAndMarkActive(rentalId, pickedFile);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF207866), foregroundColor: Colors.white),
            ),
          ],
        );
      }
    );
  }

  Future<void> _uploadProofAndMarkActive(int rentalId, XFile image) async {
    setState(() => _isLoading = true);
    try {
      final bytes = await image.readAsBytes();
      final fileExt = image.name.contains('.')
          ? image.name.split('.').last
          : 'jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$rentalId.$fileExt';
      
      await _supabase.storage.from('proof_of_collection').uploadBinary(
        fileName, 
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      
      final imageUrl = _supabase.storage.from('proof_of_collection').getPublicUrl(fileName);
      await _updateRentalStatus(rentalId, 'Active', proofOfCollection: imageUrl);
      
    } catch (e) {
      debugPrint("Error uploading proof: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload proof: $e'), backgroundColor: Colors.red));
      if (mounted) setState(() => _isLoading = false);
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
                    _showReturnProofDialog(rentalId, selectedReturnStatus);
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

  void _showReturnProofDialog(int rentalId, String returnStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Return Photo',
          style: GoogleFonts.readexPro(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Take or choose a photo showing the equipment when it is received.',
          style: GoogleFonts.readexPro(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final image = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 70,
              );
              if (image != null) {
                _uploadReturnProof(rentalId, returnStatus, image);
              }
            },
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Upload Photo'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadReturnProof(
    int rentalId,
    String returnStatus,
    XFile image,
  ) async {
    setState(() => _isLoading = true);
    try {
      final bytes = await image.readAsBytes();
      final extension = image.name.contains('.')
          ? image.name.split('.').last
          : 'jpg';
      final fileName =
          'return_${DateTime.now().millisecondsSinceEpoch}_$rentalId.$extension';
      await _supabase.storage.from('proof_of_collection').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      final imageUrl = _supabase.storage
          .from('proof_of_collection')
          .getPublicUrl(fileName);
      await _updateRentalStatus(
        rentalId,
        'Returned',
        returnStatus: returnStatus,
        proofOfStatus: imageUrl,
      );
    } catch (e) {
      debugPrint('Error uploading return proof: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload return photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                        onPressed: () => _showCollectionDialog(r['rental_record_id']),
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
    XFile? selectedImage;
    Uint8List? selectedImageBytes;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(eq == null ? 'Add Equipment' : 'Edit Equipment', style: GoogleFonts.readexPro(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 150,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: selectedImageBytes != null
                        ? Image.memory(selectedImageBytes!, fit: BoxFit.cover)
                        : eq?['image'] != null &&
                              eq!['image'].toString().isNotEmpty
                        ? Image.network(
                            eq['image'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_not_supported_outlined,
                              size: 42,
                              color: Colors.grey,
                            ),
                          )
                        : const Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final image = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      if (image == null) return;
                      final bytes = await image.readAsBytes();
                      setDialogState(() {
                        selectedImage = image;
                        selectedImageBytes = bytes;
                      });
                    },
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      eq == null ? 'Upload Equipment Photo' : 'Replace Photo',
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  var imageUrl = eq?['image']?.toString();
                  if (selectedImage != null) {
                    imageUrl = await _uploadEquipmentImage(selectedImage!);
                  }
                  final body = jsonEncode({
                    'name': nameController.text,
                    'description': descController.text,
                    'stock': int.tryParse(stockController.text) ?? 0,
                    'admin_id': _myUserId,
                    'image': imageUrl,
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
          ),
        );
      }
    );
  }

  Future<String> _uploadEquipmentImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final extension = image.name.contains('.')
        ? image.name.split('.').last
        : 'jpg';
    final fileName =
        'equipment_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _supabase.storage.from('equipment_image').uploadBinary(
      fileName,
      bytes,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
    );
    return _supabase.storage.from('equipment_image').createSignedUrl(
      fileName,
      60 * 60 * 24 * 365 * 10,
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
                leading: Container(
                  width: 64,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: eq['image'] != null &&
                          eq['image'].toString().isNotEmpty
                      ? Image.network(
                          eq['image'],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.grey,
                        ),
                ),
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
                icon: Icon(Icons.assignment_turned_in_outlined),
                selectedIcon: Icon(Icons.assignment_turned_in),
                label: Text('Active Rentals'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Inventory'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _selectedIndex == 0
                ? _buildActiveRentals()
                : _buildInventory(),
          ),
        ],
      ),
    );
  }
}
