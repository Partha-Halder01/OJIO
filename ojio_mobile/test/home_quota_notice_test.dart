import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ojio_mobile/main.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/screens/marketplace_feed_screen.dart';
import 'package:ojio_mobile/screens/post_ad_screen.dart';
import 'package:ojio_mobile/core/marketplace_fields.dart';
import 'package:ojio_mobile/services/api_service.dart';
import 'package:ojio_mobile/widgets/app_notice.dart';
import 'package:ojio_mobile/widgets/listing_card.dart';
import 'feed_and_api_test.dart' show FeedApi, pixel;

class FullFeedApi extends FeedApi {
  @override
  Future<List<ListingModel>> fetchListings({
    int? categoryId,
    String? city,
    String? query,
    double? latitude,
    double? longitude,
    double radius = 50,
    String? feed,
    int page = 1,
    double? minPrice,
    double? maxPrice,
    bool throwOnError = false,
  }) async {
    await super.fetchListings(
      categoryId: categoryId,
      city: city,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      feed: feed,
      page: page,
    );
    return List.generate(
      page == 1 ? 20 : 1,
      (index) => ListingModel(
        id: (feed == 'recommended' ? 0 : 1000) + (page - 1) * 20 + index,
        title: '$feed item ${(page - 1) * 20 + index}',
        price: 1000,
        city: 'Kolkata',
        images: [pixel],
        createdAt: DateTime(2026),
      ),
    );
  }
}

class ProductCategoriesApi extends ApiService {
  @override
  Future<List<CategoryModel>> fetchCategories() async => [
    CategoryModel(
      id: 1,
      name: 'Mobiles',
      slug: 'mobiles',
      subcategories: [
        CategoryModel(id: 2, name: 'Smartphones', slug: 'smartphones'),
      ],
    ),
    CategoryModel(
      id: 3,
      name: 'Bikes',
      slug: 'bikes-scooters',
      subcategories: [
        CategoryModel(id: 4, name: 'Motorcycles', slug: 'motorcycles'),
      ],
    ),
    CategoryModel(
      id: 5,
      name: 'Jobs',
      slug: 'jobs',
      subcategories: [CategoryModel(id: 6, name: 'Sales', slug: 'sales')],
    ),
  ];
}

void main() {
  tearDown(AppNotice.dismiss);

  testWidgets(
    'home shows only six cards per feed and view-all paginates each feed',
    (tester) async {
      globalLatitude = 22.6;
      globalLongitude = 88.4;
      final api = FullFeedApi();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            currentCity: 'Kolkata',
            onCitySelectTap: () {},
            onProfileTap: () {},
            api: api,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, 'Recommended'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Nearby'), findsNothing);
      expect(find.text('Recommended For You'), findsOneWidget);
      expect(find.text('Nearby Items'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'View all'), findsNWidgets(2));
      expect(find.byType(ListingCard), findsNWidgets(12));
      expect(find.text('recommended item 6'), findsNothing);
      expect(find.text('nearby item 6'), findsNothing);
      for (final feed in ['recommended', 'nearby']) {
        final viewAll = find.byKey(ValueKey('view-all-$feed'));
        await tester.scrollUntilVisible(
          viewAll,
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(viewAll);
        await tester.pumpAndSettle();
        expect(find.byType(MarketplaceFeedScreen), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Load more items'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Load more items'));
        await tester.pumpAndSettle();
        expect(api.calls.last['feed'], feed);
        expect(api.calls.last['page'], 2);
        if (feed == 'nearby') {
          expect(api.calls.last['radius'], 50);
          expect(api.calls.last['latitude'], 22.6);
          expect(api.calls.last['longitude'], 88.4);
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(ListingCard), findsNWidgets(12));
      }
      expect(api.calls.length, 4);
      globalLatitude = null;
      globalLongitude = null;
    },
  );

  testWidgets(
    'messages appear at top for three seconds and disappear on navigation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [AppNoticeObserver()],
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => AppNotice.show(
                      context,
                      const SnackBar(
                        content: Text('Saved'),
                        duration: Duration(seconds: 20),
                      ),
                    ),
                    child: const Text('Show'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const Scaffold(body: Text('Another page')),
                      ),
                    ),
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('app-top-notice'))).dy,
        lessThan(100),
      );
      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.text('Saved'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Saved'), findsNothing);
      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
    },
  );

  testWidgets(
    'switching product type clears old brand and model, and jobs do not ask for car/phone details',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PostAdScreen(api: ProductCategoriesApi())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobiles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smartphones'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Apple'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Model / Variant'),
        'iPhone 14',
      );
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bikes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Motorcycles'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Royal Enfield'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Hero Cycles'), findsNothing);
      expect(find.text('iPhone 14'), findsNothing);
      expect(find.text('Apple'), findsNothing);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales'));
      await tester.pumpAndSettle();
      expect(find.text('Jobs  >  Sales'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Brand / Company'),
        findsNothing,
      );
      expect(find.text('e.g. Full-time sales executive'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('motorcycles and bicycles use different brands', () {
    expect(
      MarketplaceFields.brands('bikes-scooters', 'Motorcycles'),
      contains('Royal Enfield'),
    );
    expect(
      MarketplaceFields.brands('bikes-scooters', 'Bicycles'),
      contains('Hero Cycles'),
    );
  });

  test('user model uses admin limit and elapsed reset deadline', () {
    final user = {
      'id': 1,
      'name': 'Seller',
      'city': 'Kolkata',
      'free_ads_posted': 3,
      'free_ads_limit': 4,
    };
    expect(UserModel.fromJson(user).canPostAd, true);
    expect(UserModel.fromJson({...user, 'free_ads_limit': 3}).canPostAd, false);
    expect(
      UserModel.fromJson({
        ...user,
        'free_ads_limit': 3,
        'free_quota_resets_at': DateTime.now()
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
      }).freeAdsUsed,
      0,
    );
  });

  test(
    'profile setup receives the duplicate-number response instead of swallowing it',
    () async {
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': 'Validation failed',
              'errors': {
                'phone': [
                  'This mobile number is already used by another account.',
                ],
              },
            }),
            422,
          ),
        ),
      );
      await expectLater(
        api.updateProfile('Seller', '9876543210', 'Kolkata', '', 'India'),
        throwsA(
          predicate((error) => error.toString().contains('already used')),
        ),
      );
    },
  );
}
