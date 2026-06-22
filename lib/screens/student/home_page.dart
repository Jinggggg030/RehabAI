import 'package:rehab_ai/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:rehab_ai/utils/exercise_formatters.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rehab_ai/screens/student/chat/live_chat_page.dart';
import 'package:rehab_ai/screens/student/exercises/rehabilitation_exercises_page.dart';
import 'package:rehab_ai/screens/student/exercises/exercise_details_page.dart';
import 'package:rehab_ai/screens/student/appointments/my_appointments_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rehab_ai/widgets/futuristic_home_dashboard.dart';
import 'package:rehab_ai/screens/student/progress_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _bannerController = PageController(
    viewportFraction: 0.95,
  );
  final TextEditingController _aiAdviceController = TextEditingController();

  String userName = '';
  bool isLoading = true;
  bool hasActiveChat = false;
  List<dynamic> todaysRoutine = [];
  List<dynamic> quickAccess = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();

      // Fetch User Name
      final userRes = await http.get(
        Uri.parse('$apiUrl/users/profile/${user.id}'),
      );
      int? myUserId;
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        myUserId = userData['user_id'];
        if (mounted) {
          setState(() {
            userName = _formatName(userData['username'] ?? '');
          });
        }
      }

      if (myUserId != null) {
        // Check for active Live Chat Session
        final sessionRes = await supabase
            .from('Live_Chat_Session')
            .select('session_id')
            .eq('student_id', myUserId)
            .eq('session_status', 'Active')
            .maybeSingle();

        if (mounted) {
          setState(() {
            hasActiveChat = sessionRes != null;
          });
        }

        // Fetch Today's Routine
        final routineRes = await http.get(
          Uri.parse('$apiUrl/students/$myUserId/prescribed_exercises'),
        );
        if (routineRes.statusCode == 200) {
          final routineData = jsonDecode(routineRes.body)['exercises'] ?? [];
          if (mounted) {
            setState(() {
              todaysRoutine = routineData;
            });
          }
        }
      }

      // Fetch Quick Access (All exercises)
      final exercisesRes = await http.get(Uri.parse('$apiUrl/exercises'));
      if (exercisesRes.statusCode == 200) {
        final exercisesData = jsonDecode(exercisesRes.body)['exercises'] ?? [];
        if (mounted) {
          setState(() {
            quickAccess = exercisesData;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching home data: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _aiAdviceController.dispose();
    super.dispose();
  }

  String _formatName(String fullName) {
    if (fullName.isEmpty) return '';
    List<String> parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';

    final lowerName = fullName.toLowerCase();
    if (lowerName.contains(' bin ') ||
        lowerName.contains(' binti ') ||
        lowerName.contains(' a/l ') ||
        lowerName.contains(' a/p ') ||
        lowerName.contains(' anak ')) {
      return parts.first;
    }

    if (parts.length == 3) {
      return '${parts[1]} ${parts[2]}';
    }

    return parts.first;
  }

  void _submitAiAdvice() {
    final text = _aiAdviceController.text.trim();
    if (text.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveChatPage(initialMessage: text),
        ),
      ).then((_) {
        _aiAdviceController.clear();
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LiveChatPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return FuturisticHomeDashboard(
      userName: userName,
      todayDate: DateFormat('EEEE, MMMM d').format(DateTime.now()),
      todaysRoutine: todaysRoutine,
      quickAccess: quickAccess,
      hasActiveChat: hasActiveChat,
      adviceController: _aiAdviceController,
      onSubmitAdvice: _submitAiAdvice,
      onOpenExercises: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RehabilitationExercisesPage()),
      ),
      onOpenProgress: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProgressPage()),
      ),
      onOpenAppointments: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyAppointmentsPage()),
      ),
      onBookAppointment: () => Navigator.push(
        context,
        PageRouteBuilder<void>(
          opaque: false,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => const MyAppointmentsPage(
            openBookingOnStart: true,
            closeAfterBooking: true,
          ),
        ),
      ),
      onOpenChat: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LiveChatPage()),
      ),
      onOpenRoutineExercise: (exercise) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ExerciseDetailsPage(isAssigned: true, exercise: exercise),
        ),
      ),
      onOpenExercise: (exercise) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ExerciseDetailsPage(isAssigned: false, exercise: exercise),
        ),
      ),
    );
  }

  // Kept temporarily as a visual fallback while preserving the original
  // data flow and callbacks during the design-system migration.
  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
    String todayDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF), // Off-white background
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1565C0)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            userName.isNotEmpty
                                ? 'Welcome Back, $userName!'
                                : 'Welcome Back!',
                            style: GoogleFonts.readexPro(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const NotificationBell(),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Date
                    Text(
                      todayDate,
                      style: GoogleFonts.readexPro(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Motivation Banners (Swipeable)
                    SizedBox(
                      height: 120,
                      child: PageView(
                        controller: _bannerController,
                        children: [
                          _buildBannerCard(
                            'Stay positive, work hard, make it happen!',
                          ),
                          _buildBannerCard('Remember to stay hydrated today!'),
                          _buildBannerCard(
                            'Consistency is the key to recovery.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.local_fire_department_outlined,
                            iconColor: Colors.deepOrange,
                            value: '0',
                            label: 'Day Streak',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.check_circle_outline,
                            iconColor: Colors.green,
                            value: '0',
                            label: 'Completed',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.access_time,
                            iconColor: Colors.blue,
                            value: '0',
                            label: 'Min Total',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Today's Progress
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Today\'s Progress',
                                style: GoogleFonts.readexPro(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '0/${todaysRoutine.length}',
                                style: GoogleFonts.readexPro(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: 0.0,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF1565C0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '0% complete',
                            style: GoogleFonts.readexPro(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Today's Routine Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today\'s Routine',
                          style: GoogleFonts.readexPro(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RehabilitationExercisesPage(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'View All',
                            style: GoogleFonts.readexPro(
                              fontSize: 12,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Routine List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: todaysRoutine.isEmpty
                          ? 1
                          : todaysRoutine.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (todaysRoutine.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 24,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Center(
                              child: Text(
                                "No exercises assigned today.",
                                style: GoogleFonts.readexPro(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          );
                        }
                        final ex = todaysRoutine[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExerciseDetailsPage(
                                  isAssigned: true,
                                  exercise: ex,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.fitness_center,
                                  color: Color(0xFF1565C0),
                                  size: 20,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ex['name'] ?? 'Exercise Name',
                                        style: GoogleFonts.readexPro(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        exerciseDisciplineLabel(ex),
                                        style: GoogleFonts.readexPro(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Divider(color: Colors.grey.shade200, thickness: 1),
                    const SizedBox(height: 24),

                    // Quick Access Title
                    Text(
                      'Quick Access',
                      style: GoogleFonts.readexPro(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Access Subtitle & Cards
                    Text(
                      'Daily Rehabilitation Exercises',
                      style: GoogleFonts.readexPro(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 130,
                      child: quickAccess.isEmpty
                          ? Center(
                              child: Text(
                                "No exercises available.",
                                style: GoogleFonts.readexPro(
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: quickAccess.length > 5
                                  ? 5
                                  : quickAccess.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final ex = quickAccess[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ExerciseDetailsPage(
                                              isAssigned: false,
                                              exercise: ex,
                                            ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 180,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF1565C0,
                                            ).withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.sports_gymnastics,
                                            color: Color(0xFF1565C0),
                                            size: 24,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          ex['name'] ?? 'Exercise',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.readexPro(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          exerciseDisciplineLabel(ex),
                                          style: GoogleFonts.readexPro(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 24),

                    // AI Temporal Advice / Live Chat
                    if (!hasActiveChat) ...[
                      Text(
                        'Start a New Live Chat',
                        style: GoogleFonts.readexPro(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _aiAdviceController,
                                decoration: InputDecoration(
                                  hintText: 'How can I help you today?',
                                  hintStyle: GoogleFonts.readexPro(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: GoogleFonts.readexPro(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                onSubmitted: (_) => _submitAiAdvice(),
                              ),
                            ),
                            IconButton(
                              onPressed: _submitAiAdvice,
                              icon: const Icon(
                                Icons.arrow_upward,
                                color: Colors.black87,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      Text(
                        'Active Live Chat',
                        style: GoogleFonts.readexPro(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LiveChatPage(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Resume Live Chat',
                                style: GoogleFonts.readexPro(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Appointment Booking
                    Text(
                      'Appointment Booking',
                      style: GoogleFonts.readexPro(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1565C0,
                              ).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: Color(0xFF1565C0),
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Need a session?',
                                  style: GoogleFonts.readexPro(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Schedule your next appointment with our physiotherapists.',
                                  style: GoogleFonts.readexPro(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const MyAppointmentsPage(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1565C0),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Book Now',
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 40), // extra padding for bottom nav
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBannerCard(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4), // Space between pages
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.readexPro(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.readexPro(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.readexPro(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
