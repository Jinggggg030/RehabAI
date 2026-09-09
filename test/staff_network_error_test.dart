import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rehab_ai/screens/admin/admin_dashboard.dart';
import 'package:rehab_ai/screens/physiotherapist/physio_dashboard.dart';
import 'package:rehab_ai/screens/physiotherapist/physio_progress_tab.dart';
import 'package:rehab_ai/screens/physiotherapist/record_session_dialog.dart';
import 'package:rehab_ai/widgets/cloud_error_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: 'API_URL=https://backend.test');
    GoogleFonts.config.allowRuntimeFetching = false;
    await Supabase.initialize(
      url: 'https://supabase.test',
      anonKey: 'test-key',
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        localStorage: const EmptyLocalStorage(),
      ),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'access_token': 'test-token',
            'token_type': 'bearer',
            'refresh_token': 'test-refresh',
            'expires_in': 3600,
            'user': {
              'id': 'staff-user',
              'app_metadata': {},
              'user_metadata': {},
              'aud': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
          200,
        ),
      ),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'staff@example.test',
      password: 'test',
    );
  });

  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets(
    'Patient retrieval shows offline error and retries to an empty success',
    (tester) async {
      var offline = true;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: PhysioPatientsTab(myUserId: 1)),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CloudErrorState), findsOneWidget);
          expect(find.text('No patients assigned.'), findsNothing);
          offline = false;
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(find.byType(CloudErrorState), findsNothing);
          expect(find.text('No patients assigned.'), findsOneWidget);
        },
        () => MockClient((_) async {
          if (offline) throw http.ClientException('offline');
          return http.Response('{"patients":[]}', 200);
        }),
      );
    },
  );

  testWidgets(
    'Patient analysis displays failed initial retrieval before its empty state',
    (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: PhysioProgressTab(physioId: 1)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CloudErrorState), findsOneWidget);
        expect(
          find.text('Assign a patient to begin monitoring.'),
          findsNothing,
        );
      }, () => MockClient((_) async => http.Response('Unavailable', 503)));
    },
  );

  testWidgets(
    'Prescription exercise failure offers retry instead of an empty form',
    (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: RecordSessionDialog(appointment: {})),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CloudErrorState), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      }, () => MockClient((_) async => http.Response('Unavailable', 503)));
    },
  );

  testWidgets(
    'Leaving a tab before a request fails does not update disposed state',
    (tester) async {
      final response = Completer<http.Response>();
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: PhysioPatientsTab(myUserId: 1)),
          ),
        );
        await tester.pumpWidget(const SizedBox());
        response.completeError(http.ClientException('offline'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }, () => MockClient((_) => response.future));
    },
  );

  testWidgets(
    'Admin bootstrap failure retries and section failures remain isolated',
    (tester) async {
      tester.view.physicalSize = const Size(2400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var offline = true;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: AdminDashboard()));
          await tester.pumpAndSettle();
          expect(find.byType(CloudErrorState), findsOneWidget);
          offline = false;
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(
            find.text('No active or approved rentals found.'),
            findsOneWidget,
          );
          await tester.tap(find.text('Equipment Inventory'));
          await tester.pumpAndSettle();
          expect(find.byType(CloudErrorState), findsOneWidget);
          expect(
            find.textContaining('server could not retrieve'),
            findsOneWidget,
          );
          await tester.tap(find.text('Active Rentals'));
          await tester.pumpAndSettle();
          expect(find.byType(CloudErrorState), findsNothing);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (offline) throw http.ClientException('offline');
          if (request.url.path.contains('/users/profile/')) {
            return http.Response('{"exists":true,"user_id":1}', 200);
          }
          if (request.url.path == '/equipment')
            return http.Response('Unavailable', 503);
          return http.Response('{"rentals":[],"physiotherapists":[]}', 200);
        }),
      );
    },
  );
}
