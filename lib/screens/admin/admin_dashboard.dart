import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rehab_ai/screens/auth/login_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:rehab_ai/theme/rehab_theme.dart';
import 'package:rehab_ai/widgets/portal_backdrop.dart';

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
  List<dynamic> _physiotherapists = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  TextEditingController? _rentalSearchController = TextEditingController();
  String? _rentalSearch = '';
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
    _rentalSearchController?.dispose();
    super.dispose();
  }

  Future<void> _initDashboard() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final apiUrl = kIsWeb
        ? 'http://127.0.0.1:8000'
        : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    final userRes = await http.get(
      Uri.parse('$apiUrl/users/profile/${user.id}'),
    );

    if (userRes.statusCode == 200) {
      final userData = jsonDecode(userRes.body);
      if (userData['exists'] == true) {
        setState(() {
          _myUserId = userData['user_id'];
        });
        _fetchRentals();
        _fetchEquipment();
        _fetchPhysiotherapists();
      }
    }
  }

  Future<void> _fetchRentals({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
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
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
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

  Future<void> _fetchPhysiotherapists() async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.get(Uri.parse('$apiUrl/admin/physiotherapists'));
      if (res.statusCode == 200) {
        setState(() {
          _physiotherapists = jsonDecode(res.body)['physiotherapists'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching physiotherapists: $e");
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
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final body = {'status': newStatus, 'admin_id': _myUserId};
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
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        _fetchRentals();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
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
          title: Text(
            'Proof of Collection',
            style: GoogleFonts.readexPro(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Please upload an image as proof of collection.',
            style: GoogleFonts.readexPro(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.readexPro(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text('Upload Photo', style: GoogleFonts.readexPro()),
              onPressed: () async {
                Navigator.pop(context);
                final pickedFile = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                );
                if (pickedFile != null) {
                  _uploadProofAndMarkActive(rentalId, pickedFile);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadProofAndMarkActive(int rentalId, XFile image) async {
    setState(() => _isLoading = true);
    try {
      final bytes = await image.readAsBytes();
      final fileExt = image.name.contains('.')
          ? image.name.split('.').last
          : 'jpg';
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$rentalId.$fileExt';

      await _supabase.storage
          .from('proof_of_collection')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl = _supabase.storage
          .from('proof_of_collection')
          .getPublicUrl(fileName);
      await _updateRentalStatus(
        rentalId,
        'Active',
        proofOfCollection: imageUrl,
      );
    } catch (e) {
      debugPrint("Error uploading proof: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload proof: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
                  Text(
                    'Select Equipment Condition:',
                    style: GoogleFonts.readexPro(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedReturnStatus,
                    isExpanded: true,
                    items: ['Good', 'Damaged', 'Lost']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
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
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.readexPro(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showReturnProofDialog(rentalId, selectedReturnStatus);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                  ),
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.readexPro(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
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
      await _supabase.storage
          .from('proof_of_collection')
          .uploadBinary(
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
    final allActive = _rentals
        .where((r) => r['status'] == 'Approved' || r['status'] == 'Active' || r['status'] == 'Returned')
        .toList();
    final query = (_rentalSearch ?? '').trim().toLowerCase();
    final active = query.isEmpty
        ? allActive
        : allActive.where((r) {
            final matric = r['matric_no']?.toString().toLowerCase() ?? '';
            return matric.contains(query);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _rentalSearchController,
            onChanged: (value) => setState(() => _rentalSearch = value),
            decoration: InputDecoration(
              labelText: 'Search by matric number',
              hintText: 'Enter student matric number',
              prefixIcon: const Icon(Icons.badge_outlined),
              suffixIcon: (_rentalSearch ?? '').isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _rentalSearchController?.clear();
                        setState(() => _rentalSearch = '');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (active.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                query.isEmpty
                    ? 'No active or approved rentals found.'
                    : 'No matching active rentals found.',
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                            Text(
                              "Student: ${r['student_name']}",
                              style: GoogleFonts.readexPro(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                             Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: r['status'] == 'Approved'
                                    ? Colors.orange.shade100
                                    : (r['status'] == 'Returned' ? Colors.blue.shade100 : Colors.green.shade100),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                r['status'] == 'Returned' ? 'Completed' : r['status'],
                                style: GoogleFonts.readexPro(
                                  fontSize: 12,
                                  color: r['status'] == 'Approved'
                                      ? Colors.orange.shade800
                                      : (r['status'] == 'Returned' ? Colors.blue.shade800 : Colors.green.shade800),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Matric No: ${r['matric_no'] ?? 'Not provided'}",
                          style: GoogleFonts.readexPro(
                            fontSize: 13,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Equipment: ${r['equipment_name']}",
                          style: GoogleFonts.readexPro(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Collection: ${r['collection_date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(r['collection_date'])) : 'Unknown'}",
                          style: GoogleFonts.readexPro(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (r['status'] == 'Approved')
                              ElevatedButton(
                                onPressed: () => _showCollectionDialog(
                                  r['rental_record_id'],
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565C0),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Mark Collected'),
                              ),
                            if (r['status'] == 'Active')
                              ElevatedButton(
                                onPressed: () =>
                                    _showReturnDialog(r['rental_record_id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Mark Returned'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showEquipmentDialog([Map<String, dynamic>? eq]) {
    final nameController = TextEditingController(text: eq?['name'] ?? '');
    final descController = TextEditingController(
      text: eq?['description'] ?? '',
    );
    final stockController = TextEditingController(
      text: (eq?['stock'] ?? 0).toString(),
    );
    XFile? selectedImage;
    Uint8List? selectedImageBytes;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              eq == null ? 'Add Equipment' : 'Edit Equipment',
              style: GoogleFonts.readexPro(fontWeight: FontWeight.bold),
            ),
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
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    final apiUrl = kIsWeb
                        ? 'http://127.0.0.1:8000'
                        : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000')
                              .trim();
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
                      res = await http.post(
                        Uri.parse('$apiUrl/admin/equipment'),
                        headers: {'Content-Type': 'application/json'},
                        body: body,
                      );
                    } else {
                      res = await http.put(
                        Uri.parse(
                          '$apiUrl/admin/equipment/${eq['equipment_id']}',
                        ),
                        headers: {'Content-Type': 'application/json'},
                        body: body,
                      );
                    }
                    if (res.statusCode == 200) {
                      _fetchEquipment();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Saved successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint("Error saving equipment: $e");
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _uploadEquipmentImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final extension = image.name.contains('.')
        ? image.name.split('.').last
        : 'jpg';
    final fileName =
        'equipment_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _supabase.storage
        .from('equipment_image')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
    return _supabase.storage
        .from('equipment_image')
        .createSignedUrl(fileName, 60 * 60 * 24 * 365 * 10);
  }

  Future<void> _deleteEquipment(int id) async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.delete(Uri.parse('$apiUrl/admin/equipment/$id'));
      if (res.statusCode == 200) {
        _fetchEquipment();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error deleting equipment: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildInventory() {
    if (_isLoading && _equipment.isEmpty)
      return const Center(child: CircularProgressIndicator());
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 80,
          ),
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
                  child:
                      eq['image'] != null && eq['image'].toString().isNotEmpty
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
                title: Text(
                  eq['name'],
                  style: GoogleFonts.readexPro(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Stock: ${eq['stock']}\n${eq['description'] ?? ''}",
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
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
                            content: const Text(
                              'Are you sure you want to delete this equipment?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(c);
                                  _deleteEquipment(eq['equipment_id']);
                                },
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
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
            backgroundColor: const Color(0xFF1565C0),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _deletePhysiotherapist(int userId) async {
    setState(() => _isLoading = true);
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.delete(Uri.parse('$apiUrl/admin/physiotherapists/$userId'));
      if (res.statusCode == 200) {
        _fetchPhysiotherapists();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Physiotherapist deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = jsonDecode(res.body)['detail'] ?? 'Failed to delete';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error deleting physiotherapist: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildPhysiotherapists() {
    if (_isLoading && _physiotherapists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        _physiotherapists.isEmpty
            ? Center(
                child: Text(
                  'No physiotherapists registered yet.',
                  style: GoogleFonts.readexPro(color: Colors.grey.shade600),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 80,
                ),
                itemCount: _physiotherapists.length,
                itemBuilder: (context, index) {
                  final p = _physiotherapists[index];
                  final isActive = p['supabase_id'] != null;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                        child: Icon(
                          Icons.person_outline,
                          color: isActive ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            p['username'],
                            style: GoogleFonts.readexPro(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.shade100 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Pending Setup',
                              style: GoogleFonts.readexPro(
                                fontSize: 10,
                                color: isActive ? Colors.green.shade800 : Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Specialization: ${p['specialization']}",
                              style: GoogleFonts.readexPro(
                                color: Colors.blueGrey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text("Email: ${p['email']}"),
                            Text("Phone: ${p['contact_number']}"),
                            Text("IC/Passport: ${p['identity_number']}"),
                            if (p['address'] != null && p['address'].toString().isNotEmpty)
                              Text("Address: ${p['address']}"),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showPhysiotherapistDialog(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete Physiotherapist?'),
                                  content: Text(
                                    'Are you sure you want to delete ${p['username']}? This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(c);
                                        _deletePhysiotherapist(p['user_id']);
                                      },
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
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
            onPressed: () => _showPhysiotherapistDialog(),
            backgroundColor: const Color(0xFF1565C0),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showPhysiotherapistDialog([Map<String, dynamic>? physio]) {
    final isEdit = physio != null;
    final nameController = TextEditingController(text: physio?['username'] ?? '');
    final emailController = TextEditingController(text: physio?['email'] ?? '');
    final identityController = TextEditingController(text: physio?['identity_number'] ?? '');
    final contactController = TextEditingController(text: physio?['contact_number'] ?? '');
    final addressController = TextEditingController(text: physio?['address'] ?? '');
    final specController = TextEditingController(text: physio?['specialization'] ?? '');
    String selectedGender = physio?['gender'] ?? 'Male';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              isEdit ? 'Edit Physiotherapist' : 'Add Physiotherapist',
              style: GoogleFonts.readexPro(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email Address'),
                    enabled: !isEdit,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: identityController,
                    decoration: const InputDecoration(labelText: 'Identity Number (IC/Passport)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(labelText: 'Contact Number'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: ['Male', 'Female']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedGender = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: specController,
                    decoration: const InputDecoration(labelText: 'Specialization'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty ||
                      emailController.text.trim().isEmpty ||
                      identityController.text.trim().isEmpty ||
                      contactController.text.trim().isEmpty ||
                      specController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all required fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    final apiUrl = kIsWeb
                        ? 'http://127.0.0.1:8000'
                        : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
                    final body = jsonEncode({
                      'username': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'identity_number': identityController.text.trim(),
                      'contact_number': contactController.text.trim(),
                      'gender': selectedGender,
                      'specialization': specController.text.trim(),
                      'address': addressController.text.trim(),
                    });
                    http.Response res;
                    if (!isEdit) {
                      res = await http.post(
                        Uri.parse('$apiUrl/admin/physiotherapists'),
                        headers: {'Content-Type': 'application/json'},
                        body: body,
                      );
                    } else {
                      res = await http.put(
                        Uri.parse('$apiUrl/admin/physiotherapists/${physio['user_id']}'),
                        headers: {'Content-Type': 'application/json'},
                        body: body,
                      );
                    }
                    if (res.statusCode == 200) {
                      _fetchPhysiotherapists();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEdit ? 'Updated successfully' : 'Pre-registered successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      final error = jsonDecode(res.body)['detail'] ?? 'Failed to save';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error), backgroundColor: Colors.red),
                      );
                    }
                  } catch (e) {
                    debugPrint("Error saving physiotherapist: $e");
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final compactNavigation = MediaQuery.sizeOf(context).width < 1400;
    return Scaffold(
      backgroundColor: RehabColors.portalBackground,
      body: PortalBackdrop(
        accent: RehabColors.purple,
        child: Row(
          children: [
            Container(
              width: compactNavigation ? 82 : 236,
              margin: EdgeInsets.all(compactNavigation ? 10 : 14),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF16142B), Color(0xFF40356F)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: RehabColors.purple.withValues(alpha: 0.20),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 74,
                    padding: EdgeInsets.symmetric(
                      horizontal: compactNavigation ? 15 : 18,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const _AdminLogo(),
                        if (!compactNavigation) ...[
                          const SizedBox(width: 11),
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RehabAI',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                'Admin Panel',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _adminNavItem(
                    0,
                    Icons.assignment_turned_in_outlined,
                    'Active Rentals',
                    compact: compactNavigation,
                  ),
                  _adminNavItem(
                    1,
                    Icons.inventory_2_outlined,
                    'Equipment Inventory',
                    compact: compactNavigation,
                  ),
                  _adminNavItem(
                    2,
                    Icons.people_outline,
                    'Physiotherapists',
                    compact: compactNavigation,
                  ),
                  const Spacer(),
                  if (!compactNavigation)
                    const PortalSystemStatus(label: 'Operations network online')
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Tooltip(
                        message: 'Operations network online',
                        child: Icon(
                          Icons.circle,
                          color: Color(0xFF4ADE80),
                          size: 9,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton.icon(
                      onPressed: () async {
                        await _supabase.auth.signOut();
                        if (mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: compactNavigation
                          ? const SizedBox.shrink()
                          : const Text('Exit Portal'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        minimumSize: const Size(double.infinity, 46),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 82,
                    margin: const EdgeInsets.fromLTRB(0, 14, 14, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: RehabColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: RehabColors.purple.withValues(alpha: 0.08),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedIndex == 0
                                    ? 'Rental Operations'
                                    : _selectedIndex == 1
                                        ? 'Inventory Intelligence'
                                        : 'Physiotherapist Directory',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.hub_outlined,
                                    size: 12,
                                    color: RehabColors.purple,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'OPERATIONS COMMAND CENTER',
                                    style: TextStyle(
                                      fontSize: 9,
                                      letterSpacing: 1.1,
                                      color: RehabColors.subtle,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!compactNavigation) ...[
                          PortalMetric(
                            icon: Icons.local_shipping_outlined,
                            value:
                                '${_rentals.where((r) => r['status'] == 'Approved' || r['status'] == 'Active').length}',
                            label: 'ACTIVE RENTALS',
                            accent: RehabColors.purple,
                          ),
                          const SizedBox(width: 8),
                          PortalMetric(
                            icon: Icons.inventory_2_outlined,
                            value: '${_equipment.length}',
                            label: 'ASSET TYPES',
                            accent: RehabColors.cyan,
                          ),
                        ],
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          tooltip: 'Refresh data',
                          onPressed: () {
                            _fetchRentals();
                            _fetchEquipment();
                            _fetchPhysiotherapists();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        const SizedBox(width: 10),
                        if (!compactNavigation)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F0FF),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: RehabColors.admin,
                                  child: Icon(
                                    Icons.admin_panel_settings,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Administrator',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ColoredBox(
                          color: Colors.white,
                          child: _selectedIndex == 0
                              ? _buildActiveRentals()
                              : _selectedIndex == 1
                                  ? _buildInventory()
                                  : _buildPhysiotherapists(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminNavItem(
    int index,
    IconData icon,
    String label, {
    bool compact = false,
  }) {
    final selected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: Tooltip(
          message: compact ? label : '',
          child: ListTile(
            dense: true,
            contentPadding: compact
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 16),
            horizontalTitleGap: compact ? 0 : 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            leading: compact
                ? null
                : Icon(
                    icon,
                    color: selected ? const Color(0xFFC4B5FD) : Colors.white54,
                    size: 19,
                  ),
            title: compact
                ? Center(
                    child: Icon(
                      icon,
                      color: selected
                          ? const Color(0xFFC4B5FD)
                          : Colors.white54,
                      size: 19,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
            onTap: () => setState(() => _selectedIndex = index),
          ),
        ),
      ),
    );
  }
}

class _AdminLogo extends StatelessWidget {
  const _AdminLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF22D3EE)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: RehabColors.purple.withValues(alpha: 0.35),
            blurRadius: 14,
          ),
        ],
      ),
      child: const Icon(
        Icons.health_and_safety_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
