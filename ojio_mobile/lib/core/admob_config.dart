import 'package:flutter/foundation.dart';

class AdMobConfig {
  static const androidBannerId = 'ca-app-pub-9962423610902602/3953381316';
  static const androidTestBannerId = 'ca-app-pub-3940256099942544/9214589741';
  static const iosTestBannerId = 'ca-app-pub-3940256099942544/2435281174';
  static const forceTestAds = bool.fromEnvironment('ADMOB_TEST_ADS');

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get usesLiveAds =>
      isSupported &&
      defaultTargetPlatform == TargetPlatform.android &&
      kReleaseMode &&
      !forceTestAds;

  static String get bannerId => bannerIdFor(
    defaultTargetPlatform,
    isRelease: kReleaseMode,
    useTestAds: forceTestAds,
  );

  static String bannerIdFor(
    TargetPlatform platform, {
    required bool isRelease,
    bool useTestAds = false,
  }) => platform == TargetPlatform.iOS
      ? iosTestBannerId
      : isRelease && !useTestAds
      ? androidBannerId
      : androidTestBannerId;
}
