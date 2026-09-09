import 'dart:async';

import 'package:http/http.dart' as http;

class CloudRequestException implements Exception {
  final int statusCode;
  const CloudRequestException(this.statusCode);
}

/// Applies a deadline and validates responses before callers decode cloud data.
Future<http.Response> cloudGet(Uri uri, {http.Client? client}) async {
  final requestClient = client ?? http.Client();
  try {
    final response = await requestClient
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudRequestException(response.statusCode);
    }
    return response;
  } finally {
    if (client == null) requestClient.close();
  }
}

String cloudErrorMessage(Object error) {
  if (error is TimeoutException) {
    return 'The connection timed out. Data could not be retrieved. Check your internet connection and try again.';
  }
  if (error is http.ClientException) {
    return 'Unable to connect. Data could not be retrieved. Check your internet connection and try again.';
  }
  if (error is CloudRequestException) {
    if (error.statusCode == 401 || error.statusCode == 403) {
      return 'Data could not be retrieved. Please sign in again.';
    }
    return 'The server could not retrieve the data. Please try again later.';
  }
  return 'Data could not be retrieved. Please try again. If the problem continues, contact support.';
}
