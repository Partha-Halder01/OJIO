import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/core/admob_config.dart';
import 'package:ojio_mobile/widgets/admob_banner_widget.dart';
import 'package:ojio_mobile/services/admob_service.dart';

void main() {
  test('only Android release builds select the client banner', () {
    expect(
      AdMobConfig.bannerIdFor(TargetPlatform.android, isRelease: true),
      'ca-app-pub-9962423610902602/3953381316',
    );
    for (final release in [false, true]) {
      expect(
        AdMobConfig.bannerIdFor(
          TargetPlatform.android,
          isRelease: release,
          useTestAds: true,
        ),
        AdMobConfig.androidTestBannerId,
      );
      expect(
        AdMobConfig.bannerIdFor(TargetPlatform.iOS, isRelease: release),
        AdMobConfig.iosTestBannerId,
      );
    }
    expect(
      AdMobConfig.bannerIdFor(TargetPlatform.android, isRelease: false),
      AdMobConfig.androidTestBannerId,
    );
  });

  test('Android app IDs are variant-specific and publisher matches', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains(r'android:value="${admobAppId}"'));
    expect(
      gradle,
      contains(
        'manifestPlaceholders["admobAppId"] = "ca-app-pub-9962423610902602~1669998752"',
      ),
    );
    expect(
      RegExp(
        r'manifestPlaceholders\["admobAppId"\] = "ca-app-pub-3940256099942544~3347511713"',
      ).allMatches(gradle).length,
      2,
    );
    expect(
      File('../ojio-backend/public/app-ads.txt').readAsStringSync().trim(),
      'google.com, pub-9962423610902602, DIRECT, f08c47fec0942fa0',
    );
  });

  testWidgets(
    'banner makes no requests before ads are ready',
    (tester) async {
      AdMobService.instance.adsReady.value = false;
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: AdMobBannerWidget())),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AdMobBannerWidget)), Size.zero);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
