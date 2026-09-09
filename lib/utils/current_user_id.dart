import 'package:rehab_ai/services/cloud_request.dart';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rehab_ai/config/api_config.dart';

Future<int> getCurrentBackendUserId() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('No authenticated user.');
  }

  final apiUrl = ApiConfig.baseUrl;
  final response = await cloudGet(
    Uri.parse('$apiUrl/users/profile/${user.id}'),
  ).timeout(const Duration(seconds: 10));

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
