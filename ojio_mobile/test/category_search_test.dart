import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ojio_mobile/main.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/screens/search_screen.dart';
import 'package:ojio_mobile/screens/filter_bottom_sheet.dart';
import 'package:ojio_mobile/services/api_service.dart';
import 'feed_and_api_test.dart' show pixel;

class SearchApi extends ApiService {
  final calls = <Map<String, dynamic>>[];
  @override
  Future<List<CategoryModel>> fetchCategories() async => [
    CategoryModel(
      id: 80,
      name: 'Collectibles',
      slug: 'collectibles',
      subcategories: [CategoryModel(id: 81, name: 'Coins', slug: 'coins')],
    ),
    CategoryModel(id: 90, name: 'Others', slug: 'others'),
  ];
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
      'categoryId': categoryId,
      'page': page,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'radius': radius,
    });
    return List.generate(
      page == 1 ? 20 : 1,
      (index) => ListingModel(
        id: page * 100 + index,
        title: 'Item $page-$index',
        categoryId: categoryId ?? 80,
        price: 1000,
        city: 'Kolkata',
        images: [pixel],
        createdAt: DateTime(2026),
      ),
    );
  }
}

void main() {
  setUp(() {
    globalLatitude = null;
    globalLongitude = null;
  });
  testWidgets('Search uses admin categories and IDs, including renamed names', (
    tester,
  ) async {
    final api = SearchApi();
    await tester.pumpWidget(
      MaterialApp(
        home: SearchExploreScreen(
          currentCity: 'Kolkata',
          initialCategoryId: 80,
          initialCategoryName: 'Old name',
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Collectibles'), findsWidgets);
    expect(find.text('Cars'), findsNothing);
    expect(find.text('Others'), findsNothing);
    expect(find.text('Old name'), findsNothing);
    expect(api.calls.first['categoryId'], 80);
    await tester.tap(find.text('Coins'));
    await tester.pumpAndSettle();
    expect(api.calls.last['categoryId'], 81);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search loads subsequent result pages without losing category', (
    tester,
  ) async {
    final api = SearchApi();
    await tester.pumpWidget(
      MaterialApp(
        home: SearchExploreScreen(
          currentCity: 'Kolkata',
          initialCategoryId: 80,
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more results'));
    await tester.pumpAndSettle();
    expect(api.calls.last['page'], 2);
    expect(api.calls.last['categoryId'], 80);
    expect(find.text('Load more results'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'price filters are sent to API instead of filtering just the first page',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.url.queryParameters['min_price'], '500.0');
          expect(request.url.queryParameters['max_price'], '1500.0');
          expect(request.url.queryParameters['page'], '2');
          return http.Response(
            jsonEncode({
              'data': {'data': []},
            }),
            200,
          );
        }),
      );
      await api.fetchListings(minPrice: 500, maxPrice: 1500, page: 2);
    },
  );

  testWidgets(
    'filter sheet keeps existing selection and disables distance without coordinates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBottomSheet(
              onApply: (_) {},
              initialPriceRange: const RangeValues(250000, 1000000),
              initialRadius: 75,
              hasCoordinates: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<RangeSlider>(find.byType(RangeSlider)).values.start,
        250000,
      );
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(find.text('Fuel Type'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
