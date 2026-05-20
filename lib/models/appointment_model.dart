class Appointment {
  final int id;
  final String userId;
  final String bodyPart;
  final DateTime appointmentDate;
  final String status;
  final String? details; // Nullable because it can be empty

  Appointment({
    required this.id,
    required this.userId,
    required this.bodyPart,
    required this.appointmentDate,
    required this.status,
    this.details,
  });

  // This factory takes the JSON from your Python API and converts it into a Dart object
  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      userId: json['user_id'],
      bodyPart: json['body_part'],
      appointmentDate: DateTime.parse(json['appointment_date']),
      status: json['status'],
      details: json['details'],
    );
  }

  // If you want to send data BACK to Python (like creating an appointment)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'body_part': bodyPart,
      'appointment_date': appointmentDate.toIso8601String(),
      'status': status,
      'details': details,
    };
  }
}
