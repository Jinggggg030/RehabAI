import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class RentalStatusPage extends StatefulWidget {
  const RentalStatusPage({super.key});

  @override
  State<RentalStatusPage> createState() => _RentalStatusPageState();
}

class _RentalStatusPageState extends State<RentalStatusPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  List<dynamic> _rentals = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchRentals();
  }

  Future<void> _fetchRentals() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final userRes = await http.get(Uri.parse('$apiUrl/users/profile/${user.id}'));
      
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        if (userData['exists'] == true) {
          final int myUserId = userData['user_id'];
          final res = await http.get(Uri.parse('$apiUrl/rentals/student/$myUserId'));
          if (res.statusCode == 200) {
            _rentals = jsonDecode(res.body)['rentals'];
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching rentals: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Row(
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
                    'Rental Status',
                    style: GoogleFonts.readexPro(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF207866),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none, color: Color(0xFF207866)),
                  ),
                ],
              ),
            ),
            
            // Tabs
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF207866),
                indicatorWeight: 3,
                labelColor: Colors.black87,
                labelStyle: GoogleFonts.readexPro(fontWeight: FontWeight.bold, fontSize: 16),
                unselectedLabelColor: Colors.grey,
                unselectedLabelStyle: GoogleFonts.readexPro(fontWeight: FontWeight.normal, fontSize: 15),
                tabs: const [
                  Tab(text: 'Request'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),
            
            // Tab Views
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRentalList(
                        rentals: _rentals.where((r) => r['status'] == 'Pending' || r['status'] == 'Rejected').toList(),
                        isRequest: true
                      ),
                      _buildRentalList(
                        rentals: _rentals.where((r) => r['status'] == 'Active' || r['status'] == 'Approved').toList(),
                        isPending: true
                      ),
                      _buildRentalList(
                        rentals: _rentals.where((r) => r['status'] == 'Returned' || r['status'] == 'Lost').toList(),
                        isCompleted: true
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalList({required List<dynamic> rentals, bool isRequest = false, bool isPending = false, bool isCompleted = false}) {
    if (rentals.isEmpty) {
      return Center(
        child: Text(
          'No rentals found.',
          style: GoogleFonts.readexPro(fontSize: 14, color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      itemCount: rentals.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildRentalCard(rentals[index], isRequest: isRequest, isPending: isPending, isCompleted: isCompleted);
      },
    );
  }

  Widget _buildRentalCard(dynamic rental, {bool isRequest = false, bool isPending = false, bool isCompleted = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Placeholder
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black87, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.image, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              // Middle Column (Title and Reason)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rental['equipment_name'] ?? 'Equipment',
                      style: GoogleFonts.readexPro(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rental Reasons:',
                      style: GoogleFonts.readexPro(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      rental['reason_description'] == 'Other (Please specify)' && rental['custom_reason'] != null
                          ? 'Other: ${rental['custom_reason']}'
                          : rental['reason_description'] ?? 'N/A',
                      style: GoogleFonts.readexPro(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isRequest) ...[
                const SizedBox(width: 8),
                // Right Column (Status)
                Text(
                  rental['status'] ?? 'Pending',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: rental['status'] == 'Rejected' ? Colors.red : Colors.orange,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: GoogleFonts.readexPro(fontSize: 12, color: Colors.black87),
              children: [
                const TextSpan(text: 'Collection Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: _formatDate(rental['collection_date'])),
              ],
            ),
          ),
          if (isPending || isCompleted) ...[
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: GoogleFonts.readexPro(fontSize: 12, color: Colors.black87),
                children: [
                  const TextSpan(text: 'Return Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: _formatDate(rental['return_date'])),
                ],
              ),
            ),
          ],
          if (isCompleted) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                rental['status'] ?? 'Completed',
                style: GoogleFonts.readexPro(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF207866),
                ),
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Pending Return',
                style: GoogleFonts.readexPro(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
