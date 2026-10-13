import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ojio_mobile/main.dart';
import 'package:ojio_mobile/screens/login_screen.dart';
import 'package:ojio_mobile/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final auth = AuthService();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth.onLogout = null;
    await auth.setAuth('old-session', {
      'id': 7,
      'name': 'Seller',
      'email': 'seller@example.com',
      'phone': '9876543210',
    });
  });
  tearDown(() async {
    auth.onLogout = null;
    await auth.logout();
  });

  test(
    'logout clears saved credentials without waiting for remote cleanup',
    () async {
      final pending = Completer<void>();
      String? cleanupSession;
      auth.onLogout = (session) {
        cleanupSession = session;
        return pending.future;
      };
      await auth.logout().timeout(const Duration(seconds: 1));
      expect(cleanupSession, 'old-session');
      expect(pending.isCompleted, isFalse);
      expect(auth.isAuthenticated, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('auth_user'), isNull);
      pending.completeError(Exception('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(auth.token, isNull);
    },
  );

  testWidgets(
    'confirmed logout opens login and removes authenticated history',
    (tester) async {
      final pending = Completer<void>();
      auth.onLogout = (_) => pending.future;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            final app = const OjioApp().build(context) as MaterialApp;
            return MaterialApp(theme: app.theme, home: const ProfileScreen());
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Log Out'));
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
      expect(pending.isCompleted, isFalse);
      final loginContext = tester.element(find.byType(LoginScreen));
      expect(Navigator.of(loginContext).canPop(), isFalse);
      pending.complete();
    },
  );
}
