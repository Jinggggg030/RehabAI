import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exercise_details_page.dart';

class RehabilitationExercisesPage extends StatefulWidget {
  const RehabilitationExercisesPage({super.key});

  @override
  State<RehabilitationExercisesPage> createState() => _RehabilitationExercisesPageState();
}

class _RehabilitationExercisesPageState extends State<RehabilitationExercisesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<dynamic> allExercises = [];
  List<dynamic> assignedExercises = [];
  bool isLoading = true;
  
  String selectedDiscipline = 'All';
  List<String> disciplines = ['All'];
  
  final String apiUrl = 'http://127.0.0.1:8000'; // Or use flutter dotenv later

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchExercises();
  }
  
  Future<void> _fetchExercises() async {
    try {
      // Fetch all exercises
      final resAll = await http.get(Uri.parse('$apiUrl/exercises'));
      if (resAll.statusCode == 200) {
        final fetchedExercises = jsonDecode(resAll.body)['exercises'] ?? [];
        
        // Extract unique disciplines
        final Set<String> discSet = {'All'};
        for (var ex in fetchedExercises) {
          if (ex['discipline'] != null) {
            discSet.add(ex['discipline']);
          }
        }
        
        setState(() {
          allExercises = fetchedExercises;
          disciplines = discSet.toList()..sort((a, b) => a == 'All' ? -1 : (b == 'All' ? 1 : a.compareTo(b)));
        });
      }
      
      // Fetch assigned exercises (assuming student_id = 1 for now)
      final resAssigned = await http.get(Uri.parse('$apiUrl/students/1/prescribed_exercises'));
      if (resAssigned.statusCode == 200) {
        setState(() {
          assignedExercises = jsonDecode(resAssigned.body)['exercises'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching exercises: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: SizedBox(
                height: 48,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
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
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Rehabilitation Exercises',
                        style: GoogleFonts.readexPro(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF207866),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar
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
                labelStyle: GoogleFonts.readexPro(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelColor: Colors.grey,
                unselectedLabelStyle: GoogleFonts.readexPro(fontWeight: FontWeight.normal, fontSize: 14),
                tabs: const [
                  Tab(text: 'Assigned'),
                  Tab(text: 'Explore'),
                ],
              ),
            ),
            
            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: disciplines.map((disc) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedDiscipline = disc;
                          });
                        },
                        child: _buildFilterChip(disc, isSelected: selectedDiscipline == disc),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : TabBarView(
                controller: _tabController,
                children: [
                  // Assigned Tab
                  _buildExercisesList(
                    assignedExercises.where((ex) => selectedDiscipline == 'All' || ex['discipline'] == selectedDiscipline).toList(), 
                    isAssigned: true
                  ),
                  // Explore Tab
                  _buildExercisesList(
                    allExercises.where((ex) => selectedDiscipline == 'All' || ex['discipline'] == selectedDiscipline).toList(), 
                    isAssigned: false
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String text, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF207866) : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.readexPro(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? const Color(0xFF207866) : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildExercisesList(List<dynamic> exercises, {required bool isAssigned}) {
    if (exercises.isEmpty) {
      return Center(
        child: Text(
          isAssigned ? 'No exercises assigned yet.' : 'No exercises found for this discipline.',
          style: GoogleFonts.readexPro(
            color: Colors.grey.shade500,
            fontSize: 16,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
      itemCount: exercises.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildExerciseCard(exercises[index], isAssigned: isAssigned);
      },
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise, {required bool isAssigned}) {
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
          // Header / Discipline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF207866).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              exercise['discipline'] ?? 'General',
              style: GoogleFonts.readexPro(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF207866),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Exercise Name
          Text(
            exercise['name'] ?? 'Unknown Exercise',
            style: GoogleFonts.readexPro(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // Details and Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  (exercise['description'] ?? '').toString().replaceAll('\n', ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExerciseDetailsPage(
                        isAssigned: isAssigned, 
                        exercise: exercise,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF207866),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  'View Details',
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
