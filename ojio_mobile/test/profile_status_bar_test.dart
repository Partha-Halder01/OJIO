import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/main.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/services/auth_service.dart';

void main() {
  testWidgets(
    'profile restores light icons after returning from edit profile',
    (tester) async {
      AuthService().token = 'test-token';
      AuthService().currentUser = UserModel.fromJson({
        'id': 7,
        'name': 'Test Seller',
        'email': 'test@example.com',
        'phone': '9876543210',
      });
      addTearDown(() {
        AuthService().token = null;
        AuthService().currentUser = null;
      });
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            final app = const OjioApp().build(context) as MaterialApp;
            return MaterialApp(theme: app.theme, home: const ProfileScreen());
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      final edit = find.text('Edit Profile');
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      final backdrop = find.byKey(
        const ValueKey('profile-status-bar-background'),
      );
      expect(tester.getTopLeft(backdrop).dy, 0);
      expect(tester.getSize(backdrop).height, 24 / tester.view.devicePixelRatio);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
    },
  );

  testWidgets('navy AppBar uses light icons without a global dark override', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          final app = const OjioApp().build(context) as MaterialApp;
          return MaterialApp(
            theme: app.theme,
            home: Scaffold(
              appBar: AppBar(
                backgroundColor: const Color(0xFF03172D),
                title: const Text('Wallet'),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
  });
}
