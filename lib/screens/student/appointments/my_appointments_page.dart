import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:rehab_ai/screens/student/chat/live_chat_page.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';

class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({
    super.key,
    this.openBookingOnStart = false,
    this.closeAfterBooking = false,
  });

  final bool openBookingOnStart;
  final bool closeAfterBooking;

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  int? _myUserId;
  bool _isLoading = true;
  List<dynamic> _upcoming = [];
  List<dynamic> _past = [];
  List<dynamic> _cancelled = [];
  List<dynamic> _cancellationReasons = [];
  List<dynamic> _availablePhysios = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initData().then((_) {
      if (!mounted || !widget.openBookingOnStart) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final launcherRoute = ModalRoute.of(context);
        await _showBookAppointmentBottomSheet(context);
        if (mounted && widget.closeAfterBooking && launcherRoute != null) {
          Navigator.of(context).removeRoute(launcherRoute);
        }
      });
    });
  }

  Future<void> _initData() async {
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
          _myUserId = userData['user_id'];
          await _fetchAppointments();
          await _fetchCancellationReasons();
        }
      }
    } catch (e) {
      debugPrint("Init Data Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAppointments() async {
    if (_myUserId == null) return;
    final apiUrl = kIsWeb
        ? 'http://127.0.0.1:8000'
        : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    final res = await http.get(
      Uri.parse('$apiUrl/appointments/student/$_myUserId'),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final all = data['appointments'] as List<dynamic>;
      final now = DateTime.now();

      setState(() {
        _cancelled = all
            .where(
              (a) =>
                  (a['status'] ?? '').toString().trim().toLowerCase() ==
                  'cancelled',
            )
            .toList();
        final notCancelled = all
            .where(
              (a) =>
                  (a['status'] ?? '').toString().trim().toLowerCase() !=
                  'cancelled',
            )
            .toList();

        _upcoming = notCancelled.where((a) {
          final time = DateTime.tryParse(a['schedule_time'] ?? '');
          return time != null && time.isAfter(now);
        }).toList();

        _past = notCancelled.where((a) {
          final time = DateTime.tryParse(a['schedule_time'] ?? '');
          return time != null && time.isBefore(now);
        }).toList();
      });
    }
  }

  Future<void> _fetchCancellationReasons() async {
    final apiUrl = kIsWeb
        ? 'http://127.0.0.1:8000'
        : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    final res = await http.get(
      Uri.parse('$apiUrl/appointments/cancellation_reasons'),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        _cancellationReasons = data['reasons'] ?? [];
      });
    }
  }

  Future<void> _fetchAvailablePhysios() async {
    if (_myUserId == null) return;
    final apiUrl = kIsWeb
        ? 'http://127.0.0.1:8000'
        : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
    final res = await http.get(
      Uri.parse('$apiUrl/appointments/available_physios/$_myUserId'),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        _availablePhysios = data['physios'] ?? [];
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
    if (widget.closeAfterBooking) {
      return const Scaffold(backgroundColor: Colors.transparent);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF), // Match HomePage background
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Container(
                height: 138,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: RehabColors.patientGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: RehabColors.primary.withValues(alpha: 0.24),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -32,
                      top: -44,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.09),
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
                                  alpha: 0.15,
                                ),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Care Schedule',
                          style: GoogleFonts.readexPro(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Your physiotherapy appointments in one place.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar
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
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Past'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Upcoming Tab
                  _buildAppointmentsList(isUpcoming: true),
                  // Past Tab
                  _buildAppointmentsList(isPast: true),
                  // Cancelled Tab
                  _buildAppointmentsList(isCancelled: true),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBookAppointmentBottomSheet(context),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Book appointment',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildAppointmentsList({
    bool isUpcoming = false,
    bool isPast = false,
    bool isCancelled = false,
  }) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    List<dynamic> list = isUpcoming ? _upcoming : (isPast ? _past : _cancelled);

    if (list.isEmpty) {
      return Center(
        child: Text(
          'No appointments found.',
          style: GoogleFonts.readexPro(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildAppointmentCard(
          list[index],
          isUpcoming: isUpcoming,
          isPast: isPast,
          isCancelled: isCancelled,
        );
      },
    );
  }

  Widget _buildAppointmentCard(
    dynamic appointment, {
    bool isUpcoming = false,
    bool isPast = false,
    bool isCancelled = false,
  }) {
    return GestureDetector(
      onTap: isUpcoming
          ? () => _showAppointmentDialog(context, appointment)
          : null,
      child: Container(
        padding: const EdgeInsets.all(18),
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
                Container(
                  width: 5,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: isCancelled
                        ? const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : RehabColors.patientGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 14),
                // Appointment Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appointment with ${appointment['physiotherapist_name']}',
                        style: GoogleFonts.readexPro(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: RehabColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: RehabColors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              DateFormat('EEE, MMM d').format(
                                DateTime.tryParse(
                                      appointment['schedule_time'] ?? '',
                                    ) ??
                                    DateTime.now(),
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: RehabColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: RehabColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('hh:mm a').format(
                                DateTime.tryParse(
                                      appointment['schedule_time'] ?? '',
                                    ) ??
                                    DateTime.now(),
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: RehabColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appointment['specialization'] ?? 'Physiotherapy',
                        style: GoogleFonts.readexPro(
                          fontSize: 12,
                          color: Colors.grey, // Light teal color
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isPast && !isCancelled) ...[
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  children: const [
                    TextSpan(
                      text: 'Prescription: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    TextSpan(text: 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Physiotherapist Review: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    TextSpan(text: appointment['evaluation'] ?? 'N/A'),
                  ],
                ),
              ),
            ],
            if (isCancelled) ...[
              const SizedBox(height: 16),
              Text(
                'Cancellation Reasons:',
                style: GoogleFonts.readexPro(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                appointment['cancellation_reason'] ?? 'N/A',
                style: GoogleFonts.readexPro(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Cancelled',
                  style: GoogleFonts.readexPro(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAppointmentDialog(BuildContext context, dynamic appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with Title and Close Button
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Appointment Details',
                      style: GoogleFonts.readexPro(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Calendar View
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay:
                        DateTime.tryParse(appointment['schedule_time'] ?? '') ??
                        DateTime.now(),
                    currentDay:
                        DateTime.tryParse(appointment['schedule_time'] ?? '') ??
                        DateTime.now(),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    availableGestures:
                        AvailableGestures.none, // Disable swiping
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Color(0xFF1565C0),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Details
                _buildDialogDetailRow(
                  'Time',
                  DateFormat('hh:mm a').format(
                    DateTime.tryParse(appointment['schedule_time'] ?? '') ??
                        DateTime.now(),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDialogDetailRow(
                  'Details',
                  appointment['specialization'] ?? 'Physiotherapy',
                ),
                const SizedBox(height: 16),
                _buildDialogDetailRow('Location', 'PKU UTeM / Online'),
                const SizedBox(height: 16),
                _buildDialogDetailRow(
                  'Reminder',
                  'Please Bring Your Matric Card\nAnd IC',
                ),
                const SizedBox(height: 32),

                // Cancel Button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close the detail dialog
                      _showCancelReasonDialog(
                        context,
                        appointment,
                      ); // Show cancel reason dialog
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Cancel Appointment',
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

  int? _selectedCancelReasonId;
  final TextEditingController _cancelOtherReasonCtrl = TextEditingController();

  void _showCancelReasonDialog(BuildContext context, dynamic appointment) {
    _selectedCancelReasonId = _cancellationReasons.isNotEmpty
        ? _cancellationReasons.first['reason_id']
        : null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                    Text(
                      'Please Select The Reason For\nAppointment Cancellation.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.readexPro(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          'Reason:',
                          style: GoogleFonts.readexPro(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedCancelReasonId,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                ),
                                items: _cancellationReasons
                                    .map<DropdownMenuItem<int>>((r) {
                                      return DropdownMenuItem<int>(
                                        value: r['reason_id'],
                                        child: Text(r['description']),
                                      );
                                    })
                                    .toList(),
                                onChanged: (val) => setState(
                                  () => _selectedCancelReasonId = val,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 80,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _cancelOtherReasonCtrl,
                        maxLines: null,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Other reason',
                          hintStyle: GoogleFonts.readexPro(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAppointmentDialog(context, appointment);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Back',
                            style: GoogleFonts.readexPro(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final reasonId = _selectedCancelReasonId;
                            if (reasonId != null) {
                              _cancelAppointment(
                                appointment['appointment_id'],
                                reasonId,
                                _cancelOtherReasonCtrl.text,
                              );
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Cancel Appointment',
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelAppointment(
    int appointmentId,
    int reasonId,
    String otherReason,
  ) async {
    try {
      final apiUrl = kIsWeb
          ? 'http://127.0.0.1:8000'
          : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
      final res = await http.put(
        Uri.parse('$apiUrl/appointments/$appointmentId/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"reason_id": reasonId, "other_reason": otherReason}),
      );
      if (res.statusCode == 200) {
        _fetchAppointments();
      }
    } catch (e) {
      debugPrint("Error cancelling appointment: $e");
    }
  }

  Future<void> _showBookAppointmentBottomSheet(BuildContext context) async {
    await _fetchAvailablePhysios();
    int? selectedPhysioId = _availablePhysios.isNotEmpty
        ? _availablePhysios.first['therapist_id']
        : null;
    DateTime _focusedDay = DateTime.now();
    DateTime? _selectedDay = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Book Appointment",
                      style: GoogleFonts.readexPro(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      "Select Physiotherapist",
                      style: GoogleFonts.readexPro(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context); // close bottom sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LiveChatPage(),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Have a new symptom or not sure who to choose? Tap here to use the Live Chat and our AI will recommend the perfect specialist!",
                                style: GoogleFonts.readexPro(
                                  fontSize: 12,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.blue,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedPhysioId,
                          items: _availablePhysios.map<DropdownMenuItem<int>>((
                            p,
                          ) {
                            return DropdownMenuItem<int>(
                              value: p['therapist_id'],
                              child: Text(
                                "${p['name']} (${p['specialization']}) ${p['recommended'] ? 'â­' : ''}",
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setModalState(() => selectedPhysioId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      "Select Date",
                      style: GoogleFonts.readexPro(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TableCalendar(
                        firstDay: DateTime.now(),
                        lastDay: DateTime.now().add(const Duration(days: 365)),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDay, day);
                        },
                        enabledDayPredicate: (day) {
                          if (selectedPhysioId == null) return true;
                          final p = _availablePhysios.firstWhere(
                            (element) =>
                                element['therapist_id'] == selectedPhysioId,
                            orElse: () => null,
                          );
                          if (p == null) return true;

                          final lStart = p['leave_start_date'];
                          final lEnd = p['leave_end_date'];
                          if (lStart == null || lEnd == null) return true;

                          try {
                            final start = DateTime.parse(lStart);
                            final end = DateTime.parse(lEnd);
                            final dayStart = DateTime(
                              day.year,
                              day.month,
                              day.day,
                            );
                            final leaveStart = DateTime(
                              start.year,
                              start.month,
                              start.day,
                            );
                            final leaveEnd = DateTime(
                              end.year,
                              end.month,
                              end.day,
                            );

                            if (dayStart.isAfter(
                                  leaveStart.subtract(const Duration(days: 1)),
                                ) &&
                                dayStart.isBefore(
                                  leaveEnd.add(const Duration(days: 1)),
                                )) {
                              return false;
                            }
                          } catch (e) {
                            debugPrint("Date parse error: $e");
                          }
                          return true;
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setModalState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        calendarStyle: CalendarStyle(
                          selectedDecoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      "Select Time",
                      style: GoogleFonts.readexPro(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (t != null) setModalState(() => selectedTime = t);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedTime.format(context),
                              style: GoogleFonts.readexPro(fontSize: 16),
                            ),
                            const Icon(Icons.access_time, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedPhysioId == null || _selectedDay == null)
                            return;
                          final dt = DateTime(
                            _selectedDay!.year,
                            _selectedDay!.month,
                            _selectedDay!.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );
                          try {
                            final apiUrl = kIsWeb
                                ? 'http://127.0.0.1:8000'
                                : (dotenv.env['API_URL'] ??
                                          'http://10.0.2.2:8000')
                                      .trim();
                            final res = await http.post(
                              Uri.parse('$apiUrl/appointments/book'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                "student_id": _myUserId,
                                "therapist_id": selectedPhysioId,
                                "schedule_time": dt.toIso8601String(),
                              }),
                            );
                            if (res.statusCode == 200) {
                              Navigator.pop(context);
                              _fetchAppointments();
                            }
                          } catch (e) {
                            debugPrint("Error booking: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Book Appointment",
                          style: GoogleFonts.readexPro(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.readexPro(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.readexPro(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
