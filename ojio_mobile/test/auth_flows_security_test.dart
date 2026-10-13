import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ojio_mobile/screens/login_screen.dart';
import 'package:ojio_mobile/screens/signup_screen.dart';
import 'package:ojio_mobile/services/api_service.dart';
import 'package:ojio_mobile/services/auth_service.dart';

class PendingAuthApi extends ApiService {
  final result = Completer<Map<String, dynamic>?>();
  int calls = 0;
  @override
  Future<Map<String, dynamic>?> login(String email, String password) {
    calls++;
    return result.future;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().onLogout = null;
    await AuthService().logout();
  });
  tearDown(() async => AuthService().logout());

  test(
    'login failures preserve server reason without clearing another session',
    () async {
      AuthService().token = 'existing-session';
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Invalid credentials provided.'}),
            401,
          ),
        ),
      );
      await expectLater(
        api.login('wrong@example.com', 'password'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Invalid credentials provided.',
          ),
        ),
      );
      expect(AuthService().token, 'existing-session');
    },
  );

  test('signup returns actionable duplicate email validation', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'Validation failed.',
            'errors': {
              'email': ['This email is already used.'],
            },
          }),
          422,
        ),
      ),
    );
    await expectLater(
      api.register('Seller', 'used@example.com', 'password'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'This email is already used.',
        ),
      ),
    );
  });

  test('malformed authentication success cannot become a session', () async {
    for (final data in [
      {'status': 'success'},
      {
        'status': 'success',
        'token': '',
        'user': {'id': 1},
      },
      {
        'status': 'success',
        'token': 'token',
        'user': {'id': 0},
      },
    ]) {
      final api = ApiService(
        client: MockClient((_) async => http.Response(jsonEncode(data), 200)),
      );
      await expectLater(
        api.login('user@example.com', 'password'),
        throwsA(isA<ApiException>()),
      );
      expect(AuthService().isAuthenticated, isFalse);
    }
  });

  testWidgets('pending login blocks duplicate submission and auth switching', (
    tester,
  ) async {
    final api = PendingAuthApi();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(api: api)));
    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.enterText(find.byType(TextField).last, 'password');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pump();
    expect(api.calls, 1);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Sign Up'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Back',
            ),
          )
          .onPressed,
      isNull,
    );
    api.result.completeError(
      const ApiException('Invalid credentials provided.', 401),
    );
    await tester.pumpAndSettle();
    expect(find.text('Invalid credentials provided.'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('cancelled mandatory contact setup clears partial sign-in', (
    tester,
  ) async {
    final api = PendingAuthApi();
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(api: api, returnToPrevious: true)),
    );
    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.enterText(find.byType(TextField).last, 'password');
    final submit = find.widgetWithText(ElevatedButton, 'Sign In');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    api.result.complete({
      'status': 'success',
      'token': 'token',
      'user': {
        'id': 1,
        'name': 'Seller',
        'email': 'user@example.com',
        'phone': null,
      },
    });
    // The sign-in spinner stays active underneath the setup route.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SignUpScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(SignUpScreen))).pop();
    await tester.pumpAndSettle();
    expect(AuthService().isAuthenticated, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Add your contact number to finish signing in.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('successful inline sign-in returns to its original page', (
    tester,
  ) async {
    final api = PendingAuthApi();
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LoginScreen(api: api, returnToPrevious: true),
                  ),
                );
              },
              child: const Text('Origin'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Origin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'seller@example.com');
    await tester.enterText(find.byType(TextField).last, 'password');
    final submit = find.widgetWithText(ElevatedButton, 'Sign In');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    api.result.complete({
      'status': 'success',
      'token': 'token',
      'user': {
        'id': 1,
        'name': 'Seller',
        'email': 'seller@example.com',
        'phone': '9876543210',
      },
    });
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Origin'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(AuthService().isAuthenticated, isTrue);
  });

  testWidgets('signup rejects malformed email before making a request', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));
    await tester.enterText(find.byType(TextField).at(0), 'Seller');
    await tester.enterText(find.byType(TextField).at(1), 'not-an-email');
    await tester.enterText(find.byType(TextField).at(2), 'password');
    final submit = find.widgetWithText(ElevatedButton, 'Sign Up');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
