import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/admob_config.dart';

abstract class AdMobGateway {
  Future<void> updateConsent();
  Future<void> collectConsent();
  Future<bool> canRequestAds();
  Future<bool> requiresPrivacyOptions();
  Future<void> showPrivacyOptions();
  Future<void> initializeAds();
}

class GoogleAdMobGateway implements AdMobGateway {
  @override
  Future<void> updateConsent() {
    final completion = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => completion.complete(),
      (error) => completion.completeError(error),
    );
    return completion.future;
  }

  @override
  Future<void> collectConsent() async {
    FormError? failure;
    await ConsentForm.loadAndShowConsentFormIfRequired((error) {
      failure = error;
    });
    if (failure != null) throw failure!;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<bool> requiresPrivacyOptions() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() async {
    FormError? failure;
    await ConsentForm.showPrivacyOptionsForm((error) {
      failure = error;
    });
    if (failure != null) throw failure!;
  }

  @override
  Future<void> initializeAds() async {
    await MobileAds.instance.initialize();
  }
}

class AdMobService {
  AdMobService({AdMobGateway? gateway, bool? supported, bool? usesLiveAds})
    : _gateway = gateway ?? GoogleAdMobGateway(),
      _supported = supported ?? AdMobConfig.isSupported,
      _usesLiveAds = usesLiveAds ?? AdMobConfig.usesLiveAds;

  static final instance = AdMobService();
  final AdMobGateway _gateway;
  final bool _supported;
  final bool _usesLiveAds;
  final adsReady = ValueNotifier<bool>(false);
  final privacyOptionsRequired = ValueNotifier<bool>(false);
  Future<void>? _initialization;
  bool _sdkInitialized = false;
  bool _privacyFormOpen = false;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!_supported) return;
    if (_usesLiveAds) {
      try {
        await _gateway.updateConsent();
        await _gateway.collectConsent();
      } catch (error) {
        // UMP can still allow ads using valid consent from a previous session.
        debugPrint('AdMob consent unavailable: $error');
      }
    }
    await _refreshReadiness();
  }

  Future<void> _refreshReadiness() async {
    try {
      if (_usesLiveAds) {
        privacyOptionsRequired.value = await _gateway.requiresPrivacyOptions();
        if (!await _gateway.canRequestAds()) {
          adsReady.value = false;
          return;
        }
      }
      if (!_sdkInitialized) {
        await _gateway.initializeAds();
        _sdkInitialized = true;
      }
      adsReady.value = true;
    } catch (error) {
      adsReady.value = false;
      debugPrint('AdMob unavailable: $error');
    }
  }

  Future<bool> showPrivacyOptions() async {
    if (!_supported || !privacyOptionsRequired.value || _privacyFormOpen) {
      return false;
    }
    _privacyFormOpen = true;
    adsReady.value = false;
    var shown = false;
    try {
      await _gateway.showPrivacyOptions();
      shown = true;
    } catch (error) {
      debugPrint('AdMob privacy options unavailable: $error');
    } finally {
      await _refreshReadiness();
      _privacyFormOpen = false;
    }
    return shown;
  }
}
