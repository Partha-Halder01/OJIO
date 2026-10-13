import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/screens/listing_photo_viewer.dart';
import 'package:ojio_mobile/screens/marketplace_feed_screen.dart';
import 'package:ojio_mobile/services/chat_unread_service.dart';
import 'package:ojio_mobile/main.dart';
import 'feed_and_api_test.dart' show FeedApi, pixel;
import 'package:ojio_mobile/screens/post_ad_screen.dart';
import 'package:ojio_mobile/services/api_service.dart';

class CategoryApi extends ApiService {
  final snapshot = List<CategoryModel>.unmodifiable([
    CategoryModel(
      id: 1,
      name: 'Mobiles',
      slug: 'mobiles',
      subcategories: [
        CategoryModel(id: 2, name: 'Smartphones', slug: 'smartphones'),
      ],
    ),
    CategoryModel(id: 3, name: 'Others', slug: 'others'),
  ]);
  @override
  Future<List<CategoryModel>> fetchCategories() async => snapshot;
}

class RetryCategoryApi extends CategoryApi {
  RetryCategoryApi(this.failWithException);
  final bool failWithException;
  int calls = 0;

  @override
  Future<List<CategoryModel>> fetchCategories() async {
    if (++calls == 1) {
      if (failWithException) throw const ApiException('Unavailable', 503);
      return [];
    }
    return super.fetchCategories();
  }
}

void main() {
  testWidgets(
    'Sell filters a read-only category snapshot without changing it',
    (tester) async {
      final api = CategoryApi();
      await tester.pumpWidget(MaterialApp(home: PostAdScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Mobiles'), findsOneWidget);
      expect(find.text('Others'), findsNothing);
      expect(api.snapshot.map((category) => category.name), [
        'Mobiles',
        'Others',
      ]);
      await tester.tap(find.text('Mobiles'));
      await tester.pumpAndSettle();
      expect(find.text('Smartphones'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final failure in [false, true]) {
    testWidgets(
      'Sell can retry ${failure ? 'failed' : 'empty'} category reads',
      (tester) async {
        final api = RetryCategoryApi(failure);
        await tester.pumpWidget(MaterialApp(home: PostAdScreen(api: api)));
        await tester.pumpAndSettle();
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Mobiles'), findsNothing);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('Mobiles'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        expect(api.calls, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Android Back retraces ad steps before returning to originating page',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostAdScreen(api: CategoryApi()),
                  ),
                ),
                child: const Text('Open ad'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open ad'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobiles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smartphones'));
      await tester.pumpAndSettle();
      expect(find.text('Item Details'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Choose Subtype'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('What are you offering?'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open ad'), findsOneWidget);
    },
  );
  test(
    'unread badge combines buying and selling and clears only opened thread',
    () {
      final unread = ChatUnreadService.instance;
      unread.reset();
      unread.setThreads([
        ChatThreadModel(
          id: 1,
          listingId: 1,
          buyerId: 10,
          sellerId: 20,
          lastMessageAt: DateTime(2026),
          unreadCount: 3,
        ),
        ChatThreadModel(
          id: 2,
          listingId: 2,
          buyerId: 20,
          sellerId: 10,
          lastMessageAt: DateTime(2026),
          unreadCount: 2,
        ),
      ]);
      expect(unread.value, 5);
      unread.clearThread(1);
      expect(unread.value, 2);
      unread.clearThread(1);
      expect(unread.value, 2);
      unread.reset();
    },
  );

  testWidgets(
    'gallery opens selected photo, supports zoom and photo navigation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListingPhotoViewer(
            images: [pixel, pixel, pixel],
            initialIndex: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsWidgets);
      await tester.tap(find.byTooltip('Next photo'));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous photo'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nearby view-all opens its cached feed without the removed shortcuts',
    (tester) async {
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
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('view-all-nearby')),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.widgetWithText(ActionChip, 'Nearby'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Recommended'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('view-all-nearby')));
      await tester.pumpAndSettle();
      expect(find.text('Nearby Items').hitTestable(), findsOneWidget);
      expect(find.byType(MarketplaceFeedScreen), findsOneWidget);
      expect(api.calls.length, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
