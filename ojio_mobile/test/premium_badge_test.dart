import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/widgets/premium_badge.dart';
import 'package:ojio_mobile/core/premium_status.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/main.dart';
import 'package:ojio_mobile/services/auth_service.dart';

void main() {
  test('expiry is strict and malformed dates fail closed', () {
    final now = DateTime.utc(2026, 10, 10);
    expect(PremiumStatus.active(true, now.toIso8601String(), now), isFalse);
    expect(PremiumStatus.active(true, 'invalid', now), isFalse);
    expect(PremiumStatus.active(false, null, now), isFalse);
    expect(PremiumStatus.active(true, null, now), isTrue);
  });

  testWidgets('diamond expiry falls back to premium then removes badge', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 10);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PremiumBadge(
            premium: true,
            diamond: true,
            until: now.add(const Duration(seconds: 2)).toIso8601String(),
            diamondUntil: now.add(const Duration(seconds: 1)).toIso8601String(),
            clock: () => now,
          ),
        ),
      ),
    );
    expect(find.text('DIAMOND'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('DIAMOND'), findsNothing);
    expect(find.text('PREMIUM'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('PREMIUM'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [280.0, 393.0]) {
    testWidgets('profile premium is top-right without overflow at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      AuthService().token = 'test';
      AuthService().currentUser = UserModel(
        id: 7,
        name: 'Seller',
        email: 'seller@example.com',
        isPremium: true,
        hasDiamondBadge: true,
        premiumUntil: DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String(),
      );
      addTearDown(() {
        AuthService().token = null;
        AuthService().currentUser = null;
      });
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            final app = const OjioApp().build(context) as MaterialApp;
            return MaterialApp(theme: app.theme, home: const ProfileScreen());
          },
        ),
      );
      await tester.pumpAndSettle();
      final badge = find.byKey(const ValueKey('profile-premium-badge'));
      expect(find.text('DIAMOND'), findsOneWidget);
      expect(tester.getTopLeft(badge).dy, greaterThan(44));
      expect(tester.getTopRight(badge).dx, width - 16);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
