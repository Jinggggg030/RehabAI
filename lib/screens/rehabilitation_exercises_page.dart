import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exercise_details_page.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class RehabilitationExercisesPage extends StatefulWidget {
  const RehabilitationExercisesPage({super.key});

  @override
  State<RehabilitationExercisesPage> createState() => _RehabilitationExercisesPageState();
}

class _RehabilitationExercisesPageState extends State<RehabilitationExercisesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<dynamic> allExercises = [];
  List<dynamic> assignedExercises = [];
  List<dynamic> myPlanExercises = [];
  bool isLoading = true;
  
  String selectedDiscipline = 'All';
  List<String> disciplines = ['All'];
  
  final String apiUrl = kIsWeb ? 'http://127.0.0.1:8000' : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchExercises();
  }
  
  Future<void> _scheduleExercise(Map<String, dynamic> exercise) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF207866), 
              onPrimary: Colors.white, 
              onSurface: Colors.black, 
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF207866), 
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF207866),
              ),
            ),
            child: child!,
          );
        },
      );
      
      if (pickedTime != null) {
        final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        
        setState(() => isLoading = true);
        try {
          final res = await http.post(
            Uri.parse('$apiUrl/students/1/scheduled_exercises'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'exercise_id': exercise['exercise_id'],
              'scheduled_date': dt.toIso8601String()
            })
          );
          if (res.statusCode == 200) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exercise scheduled successfully!')));
              _fetchExercises(); // Refresh plan
            }
          }
        } catch (e) {
          debugPrint("Schedule error: $e");
        } finally {
          setState(() => isLoading = false);
        }
      }
    }
  }

  Future<void> _cancelScheduledExercise(int scheduledId) async {
    setState(() => isLoading = true);
    try {
      final res = await http.put(
        Uri.parse('$apiUrl/scheduled_exercises/$scheduledId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'Cancelled'})
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scheduled exercise cancelled')));
          _fetchExercises(); // Refresh plan
        }
      }
    } catch (e) {
      debugPrint("Cancel error: $e");
    } finally {
      setState(() => isLoading = false);
    }
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
          if (ex['disciplines'] != null && ex['disciplines'] is List) {
            for (var d in ex['disciplines']) {
              discSet.add(d.toString());
            }
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
      
      // Fetch self-scheduled exercises
      final resScheduled = await http.get(Uri.parse('$apiUrl/students/1/scheduled_exercises'));
      if (resScheduled.statusCode == 200) {
        setState(() {
          myPlanExercises = jsonDecode(resScheduled.body)['scheduled_exercises'] ?? [];
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
                  Tab(text: 'My Plan'),
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
                    assignedExercises.where((ex) {
                      if (selectedDiscipline == 'All') return true;
                      if (ex['disciplines'] != null && ex['disciplines'] is List) {
                        return (ex['disciplines'] as List).contains(selectedDiscipline);
                      }
                      return false;
                    }).toList(), 
                    tabType: 'Assigned'
                  ),
                  // Explore Tab
                  _buildExercisesList(
                    allExercises.where((ex) {
                      if (selectedDiscipline == 'All') return true;
                      if (ex['disciplines'] != null && ex['disciplines'] is List) {
                        return (ex['disciplines'] as List).contains(selectedDiscipline);
                      }
                      return false;
                    }).toList(), 
                    tabType: 'Explore'
                  ),
                  // My Plan Tab
                  _buildExercisesList(
                    myPlanExercises.where((ex) {
                      if (selectedDiscipline == 'All') return true;
                      if (ex['disciplines'] != null && ex['disciplines'] is List) {
                        return (ex['disciplines'] as List).contains(selectedDiscipline);
                      }
                      return false;
                    }).toList(), 
                    tabType: 'MyPlan'
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

  Widget _buildExercisesList(List<dynamic> exercises, {required String tabType}) {
    if (exercises.isEmpty) {
      return Center(
        child: Text(
          tabType == 'Assigned' ? 'No exercises assigned yet.' : (tabType == 'MyPlan' ? 'No self-scheduled exercises.' : 'No exercises found for this discipline.'),
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
        return _buildExerciseCard(exercises[index], tabType: tabType);
      },
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise, {required String tabType}) {
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
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (exercise['disciplines'] != null && (exercise['disciplines'] as List).isNotEmpty)
                ...(exercise['disciplines'] as List).map<Widget>((d) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF207866).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    d.toString(),
                    style: GoogleFonts.readexPro(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF207866),
                    ),
                  ),
                )).toList()
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF207866).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'General',
                    style: GoogleFonts.readexPro(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF207866),
                    ),
                  ),
                ),
              if (exercise['requires_ai'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (exercise['ai_type'] ?? 'AI').toString().toUpperCase(),
                    style: GoogleFonts.readexPro(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ],
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
          if (tabType == 'Assigned') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  exercise['assigned_date'] != null 
                    ? DateFormat('MMM dd, yyyy').format(DateTime.parse(exercise['assigned_date']))
                    : 'Unknown date',
                  style: GoogleFonts.readexPro(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.repeat, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${exercise['assigned_sets'] ?? 0} Sets',
                  style: GoogleFonts.readexPro(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.timer_outlined, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${exercise['assigned_duration'] ?? 0} Reps/Mins',
                  style: GoogleFonts.readexPro(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ] else if (tabType == 'MyPlan') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  exercise['scheduled_date'] != null 
                    ? DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(exercise['scheduled_date']))
                    : 'Unknown date',
                  style: GoogleFonts.readexPro(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.info_outline, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Status: ${exercise['status'] ?? 'Pending'}',
                  style: GoogleFonts.readexPro(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tabType == 'Explore') ...[
                    OutlinedButton(
                      onPressed: () => _scheduleExercise(exercise),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF207866),
                        side: const BorderSide(color: Color(0xFF207866)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Schedule',
                        style: GoogleFonts.readexPro(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (tabType == 'MyPlan') ...[
                    OutlinedButton(
                      onPressed: () => _cancelScheduledExercise(exercise['schedule_id']),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.readexPro(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExerciseDetailsPage(
                            isAssigned: tabType == 'Assigned', 
                            exercise: exercise,
                            scheduleId: exercise['schedule_id'],
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
                      'Perform Now',
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
        ],
      ),
    );
  }
}
