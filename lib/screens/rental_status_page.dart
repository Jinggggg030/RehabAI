import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RentalStatusPage extends StatefulWidget {
  const RentalStatusPage({super.key});

  @override
  State<RentalStatusPage> createState() => _RentalStatusPageState();
}

class _RentalStatusPageState extends State<RentalStatusPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRentalList(isRequest: true),
                  _buildRentalList(isPending: true),
                  _buildRentalList(isCompleted: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalList({bool isRequest = false, bool isPending = false, bool isCompleted = false}) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildRentalCard(isRequest: isRequest, isPending: isPending, isCompleted: isCompleted);
      },
    );
  }

  Widget _buildRentalCard({bool isRequest = false, bool isPending = false, bool isCompleted = false}) {
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
              ),
              const SizedBox(width: 16),
              // Middle Column (Title and Reason)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '[Equipment Name]',
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
                      '[Reason]',
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
                  '[Approved/\nRejected]',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: GoogleFonts.readexPro(fontSize: 12, color: Colors.black87),
              children: const [
                TextSpan(text: 'Collection Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: '[Date]'),
              ],
            ),
          ),
          if (isPending || isCompleted) ...[
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: GoogleFonts.readexPro(fontSize: 12, color: Colors.black87),
                children: const [
                  TextSpan(text: 'Return Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '[Date]'),
                ],
              ),
            ),
          ],
          if (isCompleted) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Completed',
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

