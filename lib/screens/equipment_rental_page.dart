import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/screens/rental_status_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EquipmentRentalPage extends StatefulWidget {
  const EquipmentRentalPage({super.key});

  @override
  State<EquipmentRentalPage> createState() => _EquipmentRentalPageState();
}

class _EquipmentRentalPageState extends State<EquipmentRentalPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int? _myUserId;
  String? _accommodationType;
  String? _userAddress;

  List<dynamic> _equipmentList = [];
  List<dynamic> _categories = [];
  List<dynamic> _rentalReasons = [];
  
  Set<dynamic> _selectedCategoryIds = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
          _accommodationType = userData['accommodation_type'];
          _userAddress = userData['address'];
          
          final eqRes = await http.get(Uri.parse('$apiUrl/equipment'));
          final catRes = await http.get(Uri.parse('$apiUrl/categories'));
          final reasonRes = await http.get(Uri.parse('$apiUrl/rental_reasons'));
          
          if (eqRes.statusCode == 200) {
            _equipmentList = jsonDecode(eqRes.body)['equipment'];
          }
          if (catRes.statusCode == 200) {
            _categories = jsonDecode(catRes.body)['categories'];
          }
          if (reasonRes.statusCode == 200) {
            _rentalReasons = jsonDecode(reasonRes.body)['rental_reasons'];
          }
        }
      }
    } catch (e) {
      debugPrint("Init Data Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredEquipment {
    if (_selectedCategoryIds.isEmpty) return _equipmentList;
    return _equipmentList.where((eq) {
      final List<dynamic> catIds = eq['category_ids'] ?? [];
      return _selectedCategoryIds.every((id) => catIds.contains(id));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
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
                  Text(
                    'Equipment Rental',
                    style: GoogleFonts.readexPro(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF207866),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RentalStatusPage()),
                      );
                    },
                    icon: const Icon(Icons.list, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: GoogleFonts.readexPro(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                    suffixIcon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Body content
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sidebar (Categories)
                      Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF86B9B0).withOpacity(0.8), // light teal
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
                              child: Text(
                                'Categories',
                                style: GoogleFonts.readexPro(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            ..._categories.map((cat) => _CategoryCheckbox(
                              title: cat['description'],
                              isChecked: _selectedCategoryIds.contains(cat['category_id']),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedCategoryIds.add(cat['category_id']);
                                  } else {
                                    _selectedCategoryIds.remove(cat['category_id']);
                                  }
                                });
                                if (_scrollController.hasClients) {
                                  _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                }
                              },
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Grid of Items
                      Expanded(
                        child: GridView.builder(
                          controller: _scrollController,
                          itemCount: _filteredEquipment.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.65,
                          ),
                          itemBuilder: (context, index) {
                            return _buildEquipmentCard(context, _filteredEquipment[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentCard(BuildContext context, dynamic equipment) {
    int stock = equipment['stock'] ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image placeholder
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black87, width: 0.5),
              ),
              child: equipment['image'] != null && equipment['image'].toString().isNotEmpty
                  ? Image.network(
                      equipment['image'], 
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                    )
                  : const Icon(Icons.image, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            equipment['name'] ?? '',
            textAlign: TextAlign.center,
            style: GoogleFonts.readexPro(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            equipment['description'] ?? '',
            textAlign: TextAlign.center,
            style: GoogleFonts.readexPro(
              fontSize: 9,
              color: Colors.grey.shade500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Instock: $stock',
                style: GoogleFonts.readexPro(
                  fontSize: 8,
                  color: Colors.grey.shade400,
                ),
              ),
              GestureDetector(
                onTap: stock > 0 ? () => _showRentalDialog(context, equipment) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: stock > 0 ? const Color(0xFF207866) : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Rent',
                    style: GoogleFonts.readexPro(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRentalDialog(BuildContext context, dynamic equipment) {
    int? selectedReasonId;
    int selectedDuration = 7; // Default 7 days
    bool isSubmitting = false;
    TextEditingController customReasonController = TextEditingController();
    String collectionMethod = 'Self-Pickup';
    DateTime? collectionDate;
    TimeOfDay? collectionTime;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, size: 20, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Image Placeholder
                    Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black87),
                        ),
                        child: equipment['image'] != null && equipment['image'].toString().isNotEmpty
                            ? Image.network(
                                equipment['image'], 
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                              )
                            : const Icon(Icons.image, size: 50, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Equipment Name
                    Text(
                      equipment['name'] ?? '',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.readexPro(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Dropdowns
                    _buildReasonDropdown(selectedReasonId, (val) {
                      setModalState(() => selectedReasonId = val);
                    }),
                    if (selectedReasonId != null)
                      Builder(
                        builder: (context) {
                          final selectedReason = _rentalReasons.firstWhere((r) => r['rental_reason_id'] == selectedReasonId, orElse: () => null);
                          if (selectedReason != null && selectedReason['description'] == 'Other (Please specify)') {
                            return Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: TextField(
                                controller: customReasonController,
                                decoration: InputDecoration(
                                  hintText: 'Please specify your reason',
                                  hintStyle: GoogleFonts.readexPro(fontSize: 11, color: Colors.grey),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                style: GoogleFonts.readexPro(fontSize: 12),
                                maxLines: 2,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }
                      ),
                    const SizedBox(height: 16),
                    _buildDurationDropdown(selectedDuration, (val) {
                      if (val != null) setModalState(() => selectedDuration = val);
                    }),
                    const SizedBox(height: 16),
                    
                    // Collection Date Picker
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (picked != null) {
                                setModalState(() => collectionDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    collectionDate == null 
                                      ? 'Select Date' 
                                      : '${collectionDate!.day}/${collectionDate!.month}/${collectionDate!.year}',
                                    style: GoogleFonts.readexPro(fontSize: 12, color: collectionDate == null ? Colors.grey[600] : Colors.black87),
                                  ),
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (pickedTime != null) {
                                setModalState(() => collectionTime = pickedTime);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    collectionTime == null 
                                      ? 'Time' 
                                      : collectionTime!.format(context),
                                    style: GoogleFonts.readexPro(fontSize: 12, color: collectionTime == null ? Colors.grey[600] : Colors.black87),
                                  ),
                                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Collection Method
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: Text(
                        'Self-Pickup at Clinic',
                        style: GoogleFonts.readexPro(fontSize: 14, color: Colors.black54),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Request Rental Button
                    Center(
                      child: ElevatedButton(
                        onPressed: (selectedReasonId == null || collectionDate == null || collectionTime == null || false || isSubmitting) ? null : () async {
                          setModalState(() => isSubmitting = true);
                          try {
                            final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
                            
                            DateTime finalDate = collectionDate!;
                            finalDate = DateTime(finalDate.year, finalDate.month, finalDate.day, collectionTime!.hour, collectionTime!.minute);
                            
                            final res = await http.post(
                              Uri.parse('$apiUrl/rentals/request'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'student_id': _myUserId,
                                'equipment_id': equipment['equipment_id'],
                                'rental_reason_id': selectedReasonId,
                                'custom_reason': customReasonController.text.trim().isEmpty ? null : customReasonController.text.trim(),
                                'rental_duration': selectedDuration,
                                'collection_method': 'Self-Pickup',
                                'delivery_address': null,
                                'collection_date': finalDate.toIso8601String(),
                              }),
                            );
                            if (res.statusCode == 200) {
                              if (context.mounted) Navigator.pop(context);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Rental requested successfully!'), backgroundColor: Colors.green),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint("Error renting: $e");
                          } finally {
                            if (context.mounted) setModalState(() => isSubmitting = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF207866),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: isSubmitting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(
                          'Request Rental',
                          style: GoogleFonts.readexPro(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildReasonDropdown(int? selectedValue, ValueChanged<int?> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Reason for Rental:',
          style: GoogleFonts.readexPro(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              hint: Text('Select Reason', style: GoogleFonts.readexPro(fontSize: 11)),
              value: selectedValue,
              items: _rentalReasons.map<DropdownMenuItem<int>>((r) {
                return DropdownMenuItem<int>(
                  value: r['rental_reason_id'],
                  child: Text(r['description'], style: GoogleFonts.readexPro(fontSize: 11), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onChanged,
              icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationDropdown(int selectedValue, ValueChanged<int?> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Rental Duration:',
          style: GoogleFonts.readexPro(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: selectedValue,
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 Days', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: 14, child: Text('14 Days', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: 30, child: Text('30 Days', style: TextStyle(fontSize: 11))),
              ],
              onChanged: onChanged,
              icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black54),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryCheckbox extends StatelessWidget {
  final String title;
  final bool isChecked;
  final ValueChanged<bool?> onChanged;

  const _CategoryCheckbox({required this.title, required this.isChecked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: Checkbox(
              value: isChecked,
              onChanged: onChanged,
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF207866); // Dark teal
                }
                return Colors.white;
              }),
              checkColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 1.5),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                title,
                style: GoogleFonts.readexPro(
                  fontSize: 9,
                  color: Colors.black87,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
