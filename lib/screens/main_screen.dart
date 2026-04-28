import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/screens/home_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // List of screens for each tab
  final List<Widget> _screens = [
    const HomePage(),
    const Center(child: Text('Services Page Coming Soon')),
    const Center(child: Text('Progress Page Coming Soon')),
    const Center(child: Text('Profile Page Coming Soon')),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF207866),
          unselectedItemColor: Colors.black54,
          selectedLabelStyle: GoogleFonts.readexPro(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.readexPro(fontSize: 12),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view),
              label: 'Services',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.square_outlined), // Placeholder for Progress icon from wireframe
              activeIcon: Icon(Icons.square),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
