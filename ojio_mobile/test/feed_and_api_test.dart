import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ojio_mobile/core/marketplace_location.dart';
import 'package:ojio_mobile/main.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/services/api_service.dart';
import 'package:ojio_mobile/services/auth_service.dart';
import 'package:ojio_mobile/widgets/listing_card.dart';

const pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a4l8AAAAASUVORK5CYII=';

class FeedApi extends ApiService {
  final calls = <Map<String, dynamic>>[];
  @override
  Future<List<BannerModel>> fetchBanners() async => [];
  @override
  Future<List<CategoryModel>> fetchCategories() async => [];
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
    calls.add({
      'feed': feed,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'page': page,
    });
    return List.generate(
      feed == 'recommended' ? 8 : 12,
      (index) => ListingModel(
        id: (feed == 'recommended' ? 0 : 100) + index,
        title: '$feed item $index',
        price: 1000,
        city: city ?? 'Kolkata',
        images: [pixel],
        createdAt: DateTime(2026),
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    globalLatitude = null;
    globalLongitude = null;
  });

  test(
    'manual city choice replaces GPS coordinates and unknown cities do not fake distance',
    () {
      final mumbai = MarketplaceLocation.forCity('Mumbai');
      expect(mumbai.latitude, 19.076);
      expect(mumbai.longitude, 72.8777);
      expect(
        MarketplaceLocation.forCity('Custom Town').hasCoordinates,
        isFalse,
      );
      expect(
        MarketplaceLocation.forCity('Calcutta').latitude,
        MarketplaceLocation.forCity('Kolkata').latitude,
      );
    },
  );

  test(
    'wallet sends auth and receives balance without calling a different server',
    () async {
      AuthService().token = 'test-token';
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/wallet');
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(request.headers['Accept'], 'application/json');
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {'balance_paise': 50000},
            }),
            200,
          );
        }),
      );
      expect((await api.wallet())['balance_paise'], 50000);
      await AuthService().logout();
    },
  );

  test(
    'expired wallet sessions are cleared and show login instructions',
    () async {
      AuthService().token = 'expired';
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response('{"message":"Unauthenticated."}', 401),
        ),
      );
      await expectLater(
        api.wallet(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('log in again'),
          ),
        ),
      );
      expect(AuthService().token, isNull);
    },
  );

  test(
    'HTML route failures and validation errors become readable API errors',
    () async {
      final unavailable = ApiService(
        client: MockClient(
          (_) async => http.Response('<html>Not found</html>', 404),
        ),
      );
      await expectLater(
        unavailable.wallet(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('backend'),
          ),
        ),
      );
      final validation = ApiService(
        client: MockClient(
          (_) async => http.Response(
            '{"message":"Invalid","errors":{"amount_paise":["Minimum top-up is ₹100."]}}',
            422,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await expectLater(
        validation.paymentOrder(amountPaise: 10),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('₹100'),
          ),
        ),
      );
    },
  );

  test(
    'Google login rejects missing tokens locally and preserves backend failures',
    () async {
      var requests = 0;
      final api = ApiService(
        client: MockClient((_) async {
          requests++;
          return http.Response('{"message":"Wrong Google audience."}', 401);
        }),
      );
      await expectLater(
        api.firebaseLogin(email: 'test@example.com'),
        throwsA(isA<ApiException>()),
      );
      expect(requests, 0);
      await expectLater(
        api.firebaseLogin(email: 'test@example.com', idToken: 'signed-token'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Wrong Google audience.',
          ),
        ),
      );
      expect(requests, 1);
    },
  );

  test(
    'nearby requests explicitly send fifty km radius and selected location',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.url.queryParameters['latitude'], '19.076');
          expect(request.url.queryParameters['radius'], '50.0');
          expect(request.url.queryParameters['feed'], 'nearby');
          expect(request.url.queryParameters['page'], '2');
          return http.Response('{"status":"success","data":{"data":[]}}', 200);
        }),
      );
      await api.fetchListings(
        latitude: 19.076,
        longitude: 72.8777,
        feed: 'nearby',
        page: 2,
      );
    },
  );

  for (final size in [const Size(320, 568), const Size(393, 852)]) {
    testWidgets('home scrolls when dragging item images at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FeedApi();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            currentCity: 'Kolkata',
            onCitySelectTap: () {},
            api: api,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final scroll = find.byKey(const Key('home-feed-scroll'));
      await tester.drag(scroll, const Offset(0, -380));
      await tester.pumpAndSettle();
      final card = find.byType(ListingCard).hitTestable().first;
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
      );
      final before = scrollable.position.pixels;
      await tester.drag(card, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(before));
      expect(tester.takeException(), isNull);
      expect(api.calls.first['feed'], 'recommended');
      expect(api.calls.last['feed'], 'nearby');
      expect(api.calls.last['radius'], 50);
      expect(api.calls.last['latitude'], 22.5726);
      expect(
        tester.getTopLeft(find.text('Recommended For You')).dy,
        lessThan(tester.getTopLeft(find.text('Nearby Items')).dy),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
