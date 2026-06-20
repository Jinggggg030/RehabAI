import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

Future<int> getCurrentBackendUserId() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('No authenticated user.');
  }

  final apiUrl = kIsWeb
      ? 'http://127.0.0.1:8000'
      : (dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000').trim();
  final response = await http
      .get(Uri.parse('$apiUrl/users/profile/${user.id}'))
      .timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    throw StateError('Unable to resolve the current user.');
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final userId = (body['user_id'] as num?)?.toInt();
  if (body['exists'] != true || userId == null) {
    throw StateError('The authenticated user has no backend profile.');
  }
  return userId;
}
