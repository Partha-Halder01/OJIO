import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/core/marketplace_fields.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/services/payment_flow.dart';
import 'package:ojio_mobile/main.dart';

void main() {
  test('subcategory determines brands under mixed parent categories', () {
    expect(MarketplaceFields.brands('mobiles-electronics', 'Laptops'), contains('Dell'));
    expect(MarketplaceFields.brands('mobiles-electronics', 'Mobile Phones'), isNot(contains('Dell')));
    expect(MarketplaceFields.brands('electronics', 'Cameras'), contains('Canon'));
    expect(MarketplaceFields.brands('electronics', 'Televisions'), isNot(contains('Canon')));
    expect(MarketplaceFields.brands('vehicles', '3 Wheelers & Commercial'), contains('Ashok Leyland'));
    expect(MarketplaceFields.brands('real-estate', 'Apartments'), isEmpty);
  });

  test('location aliases match without incorrectly matching nearby towns', () {
    expect(MarketplaceFields.samePlace(' Bangalore ', 'Bengaluru'), isTrue);
    expect(MarketplaceFields.samePlace('Calcutta', 'Kolkata'), isTrue);
    expect(MarketplaceFields.samePlace('New Delhi', 'Delhi'), isTrue);
    expect(MarketplaceFields.samePlace('New Town', 'Kolkata'), isFalse);
    expect(MarketplaceFields.samePlace('', ''), isFalse);
  });

  test('diamond badge alone does not grant posting quota', () {
    final user = UserModel(id: 1, name: 'Seller', email: 'seller@example.com', freeAdsPosted: 2, hasDiamondBadge: true);
    expect(user.canPostAd, isFalse);
  });

  test('checkout identifiers are distinct valid UUIDs', () {
    final ids = List.generate(100, (_) => checkoutRequestId());
    expect(ids.toSet().length, ids.length);
    expect(ids.every((id) => RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id)), isTrue);
  });

  for (final size in [const Size(240, 320), const Size(320, 568), const Size(393, 852), const Size(768, 1024), const Size(1024, 240)]) {
    testWidgets('splash fits ${size.width} × ${size.height} without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump(const Duration(milliseconds: 1800));
      expect(tester.takeException(), isNull);
      final logo = tester.getRect(find.byType(Image).first);
      expect(logo.left, greaterThanOrEqualTo(0));
      expect(logo.right, lessThanOrEqualTo(size.width));
      expect(logo.top, greaterThanOrEqualTo(0));
      expect(logo.bottom, lessThanOrEqualTo(size.height));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
