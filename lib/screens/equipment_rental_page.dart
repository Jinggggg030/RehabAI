import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/screens/rental_status_page.dart';

class EquipmentRentalPage extends StatelessWidget {
  const EquipmentRentalPage({super.key});

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
                          const _CategoryCheckbox(title: 'Musculoskeletal/\nOrthopedic'),
                          const _CategoryCheckbox(title: 'Sports'),
                          const _CategoryCheckbox(title: 'Ergonomic'),
                          const _CategoryCheckbox(title: 'Neurological'),
                          const _CategoryCheckbox(title: 'Cardiorespiratory'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Grid of Items
                    Expanded(
                      child: GridView.builder(
                        itemCount: 10, // 6 items from the image
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.65,
                        ),
                        itemBuilder: (context, index) {
                          return _buildEquipmentCard(context);
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

  Widget _buildEquipmentCard(BuildContext context) {
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
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '[Equipment Name]',
            textAlign: TextAlign.center,
            style: GoogleFonts.readexPro(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '[description]',
            textAlign: TextAlign.center,
            style: GoogleFonts.readexPro(
              fontSize: 9,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Instock',
                style: GoogleFonts.readexPro(
                  fontSize: 8,
                  color: Colors.grey.shade400,
                ),
              ),
              GestureDetector(
                onTap: () => _showRentalDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF207866),
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

  void _showRentalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                  ),
                ),
                const SizedBox(height: 16),
                
                // Equipment Name
                Text(
                  '[Equipment name]',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.readexPro(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Dropdowns
                _buildDialogDropdownRow('Physiotherapy Session:'),
                const SizedBox(height: 16),
                _buildDialogDropdownRow('Reason for Rental:'),
                const SizedBox(height: 16),
                _buildDialogDropdownRow('Rental Duration:'),
                
                const SizedBox(height: 32),
                
                // Request Rental Button
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
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
                    child: Text(
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
      },
    );
  }

  Widget _buildDialogDropdownRow(String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.readexPro(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Row(
          children: [
            Text(
              'List',
              style: GoogleFonts.readexPro(
                fontSize: 11,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black54),
          ],
        ),
      ],
    );
  }
}

class _CategoryCheckbox extends StatefulWidget {
  final String title;

  const _CategoryCheckbox({required this.title});

  @override
  State<_CategoryCheckbox> createState() => _CategoryCheckboxState();
}

class _CategoryCheckboxState extends State<_CategoryCheckbox> {
  bool _isChecked = false;

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
              value: _isChecked,
              onChanged: (value) {
                setState(() {
                  _isChecked = value ?? false;
                });
              },
              fillColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
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
                widget.title,
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
