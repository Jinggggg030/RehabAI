import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rehab_ai/services/cloud_request.dart';
import 'package:rehab_ai/widgets/cloud_error_state.dart';

void main() {
  final uri = Uri.parse('https://example.test/equipment');

  test('Successful empty data remains a successful response', () async {
    final client = MockClient(
      (_) async => http.Response('{"equipment":[]}', 200),
    );
    expect((await cloudGet(uri, client: client)).body, '{"equipment":[]}');
    client.close();
  });

  test(
    'Offline request reports a connection failure and can be retried',
    () async {
      var offline = true;
      final client = MockClient((_) async {
        if (offline) throw http.ClientException('Failed to fetch');
        return http.Response('{"equipment":[1]}', 200);
      });
      await expectLater(
        cloudGet(uri, client: client),
        throwsA(isA<http.ClientException>()),
      );
      expect(
        cloudErrorMessage(http.ClientException('Failed to fetch')),
        contains('Check your internet connection'),
      );
      offline = false;
      expect((await cloudGet(uri, client: client)).statusCode, 200);
      client.close();
    },
  );

  test('Server errors are not treated as empty data or offline', () async {
    final client = MockClient((_) async => http.Response('Unavailable', 503));
    await expectLater(
      cloudGet(uri, client: client),
      throwsA(isA<CloudRequestException>()),
    );
    expect(
      cloudErrorMessage(const CloudRequestException(503)),
      contains('server'),
    );
    client.close();
  });

  testWidgets('A stalled request times out after 15 seconds', (tester) async {
    final client = MockClient((_) => Completer<http.Response>().future);
    final assertion = expectLater(
      cloudGet(uri, client: client),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump(const Duration(seconds: 15));
    await assertion;
    expect(cloudErrorMessage(TimeoutException('')), contains('timed out'));
    client.close();
  });

  testWidgets('Retrieval failure displays its message and a working retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CloudErrorState(
            message: cloudErrorMessage(http.ClientException('offline')),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.textContaining('Data could not be retrieved'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });
}
