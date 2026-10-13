import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart' as ads;
import 'package:ojio_mobile/core/feed_ad_placements.dart';
import 'package:ojio_mobile/core/marketplace_location.dart';
import 'package:ojio_mobile/screens/marketplace_feed_screen.dart';
import 'package:ojio_mobile/widgets/admob_banner_widget.dart';
import 'package:ojio_mobile/widgets/listing_card.dart';
import 'home_quota_notice_test.dart' show FullFeedApi;

void main() {
  test(
    'ad positions are sparse, stable, row-aligned and never at the feed ends',
    () {
      for (var seed = 0; seed < 40; seed++) {
        final placements = FeedAdPlacements(random: Random(seed));
        for (final columns in [2, 3]) {
          final previous = <int>[];
          for (var count = 0; count <= 100; count++) {
            final boundaries = placements.boundaries(
              itemCount: count,
              columns: columns,
            );
            expect(boundaries.length, lessThanOrEqualTo(3));
            expect(boundaries.take(previous.length).toList(), previous);
            for (var index = 0; index < boundaries.length; index++) {
              expect(boundaries[index], greaterThanOrEqualTo(8));
              expect(boundaries[index] % columns, 0);
              expect(boundaries[index], lessThanOrEqualTo(count - columns));
              if (index > 0) {
                expect(
                  boundaries[index] - boundaries[index - 1],
                  greaterThanOrEqualTo(8),
                );
              }
            }
            previous.clear();
            previous.addAll(boundaries);
          }
          expect(previous.length, 3);
        }
      }
      expect(
        FeedAdPlacements(
          random: Random(1),
        ).boundaries(itemCount: 100, columns: 2),
        isNot(
          FeedAdPlacements(
            random: Random(2),
          ).boundaries(itemCount: 100, columns: 2),
        ),
      );
    },
  );

  for (final feed in ['recommended', 'nearby']) {
    for (final width in [320.0, 393.0, 800.0]) {
      testWidgets(
        '$feed keeps listing order with full-width ads at width $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final api = FullFeedApi();
          final items = await api.fetchListings(feed: feed);
          await tester.pumpWidget(
            MaterialApp(
              home: MarketplaceFeedScreen(
                feed: feed,
                api: api,
                initialListings: items,
                location: const MarketplaceLocation(
                  'Kolkata',
                  latitude: 22.6,
                  longitude: 88.4,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final group = tester.widget<SliverMainAxisGroup>(
            find.byType(SliverMainAxisGroup),
          );
          final gridContext = tester.element(find.byType(SliverMainAxisGroup));
          final grids = group.children.whereType<SliverGrid>().toList();
          final ids = <int>[];
          for (final grid in grids) {
            final delegate = grid.delegate as SliverChildBuilderDelegate;
            for (
              var index = 0;
              index < delegate.estimatedChildCount!;
              index++
            ) {
              ids.add(
                (delegate.builder(gridContext, index)! as ListingCard)
                    .listing
                    .id,
              );
            }
          }
          expect(ids, items.map((item) => item.id).toList());
          final slots = group.children.whereType<SliverToBoxAdapter>().toList();
          expect(slots.length, inInclusiveRange(1, 3));
          for (final slot in slots) {
            expect((slot.child! as Padding).child, isA<AdMobBannerWidget>());
          }
          await tester.scrollUntilVisible(
            find.byKey(ValueKey('feed-listing-${items.last.id}')),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(ValueKey('feed-listing-${items.last.id}')).hitTestable(),
            findsOneWidget,
          );
          expect(api.calls.length, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'unsupported platforms show no fake promotion or empty ad box',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: AdMobBannerWidget())),
      );
      await tester.pumpAndSettle();
      expect(find.text('ADVERTISEMENT'), findsNothing);
      expect(find.text('Loading ad…'), findsNothing);
      expect(find.byType(AdWidget), findsNothing);
      expect(tester.getSize(find.byType(AdMobBannerWidget)), Size.zero);
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );

  testWidgets(
    'missing Android plugin fails quietly and collapses the slot',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ads.instanceManager.channel, (call) async {
            if (call.method == 'loadBannerAd') {
              throw MissingPluginException('Test plugin unavailable');
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ads.instanceManager.channel, null),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: SizedBox(width: 288, child: AdMobBannerWidget())),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('ADVERTISEMENT'), findsNothing);
      expect(find.byType(AdWidget), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'loaded ads use their exact native size and reload safely when the width changes',
    (tester) async {
      final loadedIds = <int>[];
      final disposedIds = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ads.instanceManager.channel, (call) async {
            if (call.method == 'loadBannerAd') {
              loadedIds.add(call.arguments['adId'] as int);
            } else if (call.method == 'getAdSize') {
              final ad =
                  ads.instanceManager.adFor(call.arguments['adId'] as int)!
                      as BannerAd;
              return AdSize(width: ad.size.width, height: 90);
            } else if (call.method == 'disposeAd') {
              disposedIds.add(call.arguments['adId'] as int);
            }
            return null;
          });
      const viewsChannel = MethodChannel('flutter/platform_views');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(viewsChannel, (call) async {
            if (call.method == 'create') return 0;
            if (call.method == 'resize') {
              return {
                'width': call.arguments['width'],
                'height': call.arguments['height'],
              };
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ads.instanceManager.channel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(viewsChannel, null);
      });
      Widget page(double width) => MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            child: const AdMobBannerWidget(adSize: AdSize.largeBanner),
          ),
        ),
      );
      await tester.pumpWidget(page(288));
      await tester.pumpAndSettle();
      final firstAd = ads.instanceManager.adFor(loadedIds.single)! as BannerAd;
      firstAd.listener.onAdLoaded!(firstAd);
      await tester.pumpAndSettle();
      expect(find.byType(AdWidget), findsOneWidget);
      expect(tester.getSize(find.byType(AdWidget)), const Size(288, 90));
      expect(
        tester.getSize(find.byType(AdMobBannerWidget)).height,
        lessThan(120),
      );
      await tester.pumpWidget(page(240));
      await tester.pumpAndSettle();
      expect(loadedIds.length, 2);
      expect(disposedIds, contains(loadedIds.first));
      final secondAd = ads.instanceManager.adFor(loadedIds.last)! as BannerAd;
      firstAd.listener.onAdLoaded!(firstAd);
      secondAd.listener.onAdLoaded!(secondAd);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AdWidget)), const Size(240, 90));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(disposedIds.toSet(), loadedIds.toSet());
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'each Android slot gets its own adaptive test ad and disposes it on exit',
    (tester) async {
      final loadedIds = <int>[];
      final disposedIds = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ads.instanceManager.channel, (call) async {
            if (call.method == 'loadBannerAd') {
              loadedIds.add(call.arguments['adId'] as int);
              expect(
                call.arguments['adUnitId'],
                'ca-app-pub-3940256099942544/9214589741',
              );
              expect((call.arguments['size'] as AdSize).width, 288);
              expect(call.arguments['size'], isA<InlineAdaptiveSize>());
            } else if (call.method == 'disposeAd') {
              disposedIds.add(call.arguments['adId'] as int);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ads.instanceManager.channel, null),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 288,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [AdMobBannerWidget(), AdMobBannerWidget()],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loadedIds.length, 2);
      expect(loadedIds.toSet().length, 2);
      expect(
        tester.getSize(find.byType(AdMobBannerWidget).first).height,
        lessThan(80),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(disposedIds.toSet(), loadedIds.toSet());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
