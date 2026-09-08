import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    final url = dotenv.env['API_URL']?.trim();

    if (url == null || url.isEmpty) {
      throw Exception('API_URL is not configured in .env');
    }

    return url;
  }
}