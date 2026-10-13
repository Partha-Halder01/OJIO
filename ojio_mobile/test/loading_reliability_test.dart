import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ojio_mobile/main.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/screens/search_screen.dart';
import 'package:ojio_mobile/services/api_service.dart';
import 'package:ojio_mobile/services/auth_service.dart';

import 'feed_and_api_test.dart' show pixel;

class ControlledFeedApi extends ApiService {
  final recommended = <Completer<List<ListingModel>>>[];
  final nearby = <Completer<List<ListingModel>>>[];
  final categories = <Completer<List<CategoryModel>>>[];

  @override
  Future<List<CategoryModel>> fetchCategories() {
    final request = Completer<List<CategoryModel>>();
    categories.add(request);
    return request.future;
  }

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
  }) {
    final request = Completer<List<ListingModel>>();
    (feed == 'nearby' ? nearby : recommended).add(request);
    return request.future;
  }
}

ListingModel item(int id, String title) => ListingModel(
  id: id,
  title: title,
  price: 1000,
  city: 'Kolkata',
  images: [pixel],
  createdAt: DateTime(2026),
);

Widget home(ControlledFeedApi api, {String city = 'Kolkata'}) => MaterialApp(
  home: HomeScreen(currentCity: city, onCitySelectTap: () {}, api: api),
);

List<ListingModel> homePair(int id, String title) => [
  item(id, title),
  item(id + 10000, 'Companion $title'),
];

void main() {
  setUp(() {
    globalLatitude = null;
    globalLongitude = null;
    AuthService().token = null;
    ApiService.clearCategoryCache();
  });
  tearDown(() {
    AuthService().token = null;
    ApiService.clearCategoryCache();
  });

  for (final failure in ['503', 'timeout', 'connection']) {
    test('temporary GET $failure retries once and succeeds', () async {
      var calls = 0;
      final api = ApiService(
        client: MockClient((request) async {
          calls++;
          if (calls == 1) {
            if (failure == 'timeout') throw TimeoutException('temporary');
            if (failure == 'connection')
              throw http.ClientException('temporary');
            return http.Response('{}', 503);
          }
          return http.Response('{"data":{"data":[]}}', 200);
        }),
      );
      expect(await api.fetchListings(throwOnError: true), isEmpty);
      expect(calls, 2);
    });
  }

  test('persistent GET failure stops after one retry', () async {
    var calls = 0;
    final api = ApiService(
      client: MockClient((_) async {
        calls++;
        return http.Response('{"message":"Unavailable"}', 503);
      }),
    );
    await expectLater(
      api.fetchListings(throwOnError: true),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 2);
  });

  for (final status in [401, 403, 404, 422, 429]) {
    test('GET $status is not retried', () async {
      var calls = 0;
      final api = ApiService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{"message":"Rejected"}', status);
        }),
      );
      await expectLater(
        api.fetchListings(throwOnError: true),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 1);
    });
  }

  test('payment POST is never automatically retried', () async {
    var calls = 0;
    final api = ApiService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        calls++;
        return http.Response('{"message":"Unavailable"}', 503);
      }),
    );
    await expectLater(
      api.paymentOrder(amountPaise: 10000),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });

  test('account change prevents retry under the previous session', () async {
    AuthService().token = 'old-session';
    var calls = 0;
    final api = ApiService(
      client: MockClient((_) async {
        calls++;
        AuthService().token = 'new-session';
        throw http.ClientException('temporary');
      }),
    );
    await expectLater(
      api.fetchListings(throwOnError: true),
      throwsA(isA<http.ClientException>()),
    );
    expect(calls, 1);
    expect(AuthService().token, 'new-session');
  });

  test(
    'categories share an in-flight read and reuse the short-lived cache',
    () async {
      var calls = 0;
      final response = Completer<http.Response>();
      final api = ApiService(
        cacheCategories: true,
        client: MockClient((_) {
          calls++;
          return response.future;
        }),
      );
      final first = api.fetchCategories();
      final second = api.fetchCategories();
      response.complete(
        http.Response(
          jsonEncode({
            'data': [
              {'id': 1, 'name': 'Cars', 'slug': 'cars'},
            ],
          }),
          200,
        ),
      );
      expect((await first).single.id, 1);
      expect((await second).single.id, 1);
      expect((await api.fetchCategories()).single.id, 1);
      expect(calls, 1);
    },
  );

  testWidgets(
    'Home displays recommendations while nearby and categories wait',
    (tester) async {
      final api = ControlledFeedApi();
      await tester.pumpWidget(home(api));
      api.recommended.single.complete(homePair(1, 'Loaded recommendation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Loaded recommendation'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-nearby-loading')), findsOneWidget);
      api.nearby.single.completeError(const ApiException('Unavailable', 503));
      api.categories.single.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('Loaded recommendation'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-nearby-loading')), findsNothing);
    },
  );

  testWidgets('failed refresh retains existing items in both Home sections', (
    tester,
  ) async {
    final api = ControlledFeedApi();
    await tester.pumpWidget(home(api));
    api.recommended.single.complete(homePair(1, 'Existing recommendation'));
    api.nearby.single.complete(homePair(2, 'Existing nearby'));
    api.categories.single.complete([]);
    await tester.pumpAndSettle();
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    expect(find.text('Existing recommendation'), findsOneWidget);
    expect(find.text('Existing nearby'), findsOneWidget);
    api.recommended.last.completeError(const ApiException('Unavailable', 503));
    api.nearby.last.completeError(const ApiException('Unavailable', 503));
    api.categories.last.complete([]);
    await refresh;
    await tester.pumpAndSettle();
    expect(find.text('Existing recommendation'), findsOneWidget);
    expect(find.text('Existing nearby'), findsOneWidget);
  });

  testWidgets('old location responses cannot overwrite the new location', (
    tester,
  ) async {
    final api = ControlledFeedApi();
    await tester.pumpWidget(home(api));
    await tester.pumpWidget(home(api, city: 'Mumbai'));
    expect(api.nearby.length, 2);
    api.recommended.last.complete(homePair(3, 'New recommendation'));
    api.nearby.last.complete(homePair(4, 'New nearby'));
    api.categories.last.complete([]);
    await tester.pumpAndSettle();
    api.recommended.first.complete(homePair(1, 'Old recommendation'));
    api.nearby.first.complete(homePair(2, 'Old nearby'));
    api.categories.first.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('New nearby'), findsOneWidget);
    expect(find.text('Old nearby'), findsNothing);
    expect(find.text('Old recommendation'), findsNothing);
  });

  testWidgets('Search starts loading listings without waiting for categories', (
    tester,
  ) async {
    final api = ControlledFeedApi();
    await tester.pumpWidget(
      MaterialApp(
        home: SearchExploreScreen(currentCity: 'Kolkata', api: api),
      ),
    );
    expect(api.recommended.length, 1);
    api.recommended.single.complete([item(1, 'Search result')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Search result'), findsOneWidget);
    api.categories.single.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
