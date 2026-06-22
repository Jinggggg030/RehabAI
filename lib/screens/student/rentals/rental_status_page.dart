import 'package:rehab_ai/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';
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

class _RentalStatusPageState extends State<RentalStatusPage>
    with SingleTickerProviderStateMixin {
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

      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final userRes = await http.get(
        Uri.parse('$apiUrl/users/profile/${user.id}'),
      );

      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        if (userData['exists'] == true) {
          final int myUserId = userData['user_id'];
          final res = await http.get(
            Uri.parse('$apiUrl/rentals/student/$myUserId'),
          );
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
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Container(
                height: 142,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: RehabColors.darkGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: RehabColors.primary.withValues(alpha: 0.25),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -28,
                      top: -42,
                      child: Container(
                        width: 125,
                        height: 125,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.cyanAccent.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => Navigator.pop(context),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.14,
                                ),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const Spacer(),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const IconTheme(
                                data: IconThemeData(color: Colors.white),
                                child: NotificationBell(),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Rental Journey',
                          style: GoogleFonts.readexPro(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Track every request from approval to return.',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: RehabColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: RehabColors.primary,
                  borderRadius: BorderRadius.circular(13),
                ),
                labelColor: Colors.white,
                labelStyle: GoogleFonts.readexPro(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                unselectedLabelColor: RehabColors.muted,
                tabs: const [
                  Tab(text: 'Requests'),
                  Tab(text: 'Active'),
                  Tab(text: 'History'),
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
                          rentals: _rentals
                              .where(
                                (r) =>
                                    r['status'] == 'Pending' ||
                                    r['status'] == 'Approved' ||
                                    r['status'] == 'Rejected',
                              )
                              .toList(),
                          isRequest: true,
                        ),
                        _buildRentalList(
                          rentals: _rentals
                              .where((r) => r['status'] == 'Active')
                              .toList(),
                          isPending: true,
                        ),
                        _buildRentalList(
                          rentals: _rentals
                              .where(
                                (r) =>
                                    r['status'] == 'Returned' ||
                                    r['status'] == 'Lost',
                              )
                              .toList(),
                          isCompleted: true,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalList({
    required List<dynamic> rentals,
    bool isRequest = false,
    bool isPending = false,
    bool isCompleted = false,
  }) {
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
        return _buildRentalCard(
          rentals[index],
          isRequest: isRequest,
          isPending: isPending,
          isCompleted: isCompleted,
        );
      },
    );
  }

  Widget _buildRentalCard(
    dynamic rental, {
    bool isRequest = false,
    bool isPending = false,
    bool isCompleted = false,
  }) {
    if (isCompleted) return _buildCompletedRentalCard(rental);

    final imageUrl = rental['equipment_image']?.toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RehabColors.border),
        boxShadow: [
          BoxShadow(
            color: RehabColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                width: 88,
                height: 96,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: RehabColors.primaryLight,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: RehabColors.subtle,
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        color: RehabColors.subtle,
                        size: 34,
                      ),
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
                    const SizedBox(height: 6),
                    Text(
                      'Reason',
                      style: GoogleFonts.readexPro(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      rental['reason_description'] ==
                                  'Other (Please specify)' &&
                              rental['custom_reason'] != null
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
                    color: rental['status'] == 'Rejected'
                        ? RehabColors.danger
                        : rental['status'] == 'Approved'
                        ? RehabColors.green
                        : RehabColors.amber,
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
                const TextSpan(
                  text: 'Collection Date: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: _formatDate(rental['collection_date'])),
              ],
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: GoogleFonts.readexPro(
                  fontSize: 12,
                  color: Colors.black87,
                ),
                children: [
                  const TextSpan(
                    text: 'Return Date: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: _formatDate(rental['return_date'])),
                ],
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

  Widget _buildCompletedRentalCard(dynamic rental) {
    final photoUrl = rental['proof_of_status']?.toString();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RehabColors.border),
        boxShadow: [
          BoxShadow(
            color: RehabColors.primary.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: RehabColors.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: RehabColors.green,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              rental['equipment_name'] ?? 'Equipment',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.readexPro(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: RehabColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: hasPhoto ? () => _showReturnPhoto(photoUrl!) : null,
            icon: const Icon(Icons.image_outlined, size: 17),
            label: Text(hasPhoto ? 'View photo' : 'No photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: RehabColors.primary,
              side: const BorderSide(color: RehabColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReturnPhoto(String photoUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Equipment Return Photo',
                      style: GoogleFonts.readexPro(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.65,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: InteractiveViewer(
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const SizedBox(
                              height: 240,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 220,
                        child: Center(
                          child: Text('Unable to load the return photo.'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
