import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/screens/premium_preview_screen.dart';
import 'package:ojio_mobile/services/auth_service.dart';
import 'package:ojio_mobile/widgets/listing_card.dart';

void main() {
  test('listing expiry metadata comes from its seller', () {
    final item = ListingModel.fromJson({
      'id': 1,
      'title': 'Phone',
      'price': 100,
      'city': 'Kolkata',
      'user': {
        'id': 7,
        'is_premium': true,
        'has_diamond_badge': true,
        'premium_until': '2026-11-10T00:00:00Z',
        'diamond_badge_until': '2026-10-20T00:00:00Z',
      },
    });
    expect(item.sellerPremiumUntil, '2026-11-10T00:00:00Z');
    expect(item.sellerDiamondBadgeUntil, '2026-10-20T00:00:00Z');
  });

  testWidgets(
    'preview switches badges without changing the logged-in account',
    (tester) async {
      final auth = AuthService();
      final user = UserModel(
        id: 7,
        name: 'Real user',
        email: 'real@example.com',
      );
      auth.token = 'existing-session';
      auth.currentUser = user;
      addTearDown(() {
        auth.token = null;
        auth.currentUser = null;
      });
      await tester.pumpWidget(const MaterialApp(home: PremiumPreviewScreen()));
      await tester.runAsync(
        () => rootBundle.load('assets/images/cat_mobiles.png'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListingCard), findsOneWidget);
      expect(find.text('DIAMOND'), findsNWidgets(2));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Premium'));
      await tester.pumpAndSettle();
      expect(find.text('PREMIUM'), findsNWidgets(2));
      expect(find.text('DIAMOND'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Expired'));
      await tester.pumpAndSettle();
      expect(find.text('DIAMOND'), findsNothing);
      expect(find.text('PREMIUM'), findsNothing);
      expect(auth.token, 'existing-session');
      expect(identical(auth.currentUser, user), isTrue);
      expect(auth.currentUser?.isPremium, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
