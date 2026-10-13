import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/services/admob_service.dart';

class FakeAdMobGateway implements AdMobGateway {
  final calls = <String>[];
  bool allowed = true;
  bool privacyRequired = true;
  bool failConsent = false;
  bool failSdk = false;
  bool failPrivacy = false;
  Completer<void>? consentWait;
  Completer<void>? privacyWait;

  @override
  Future<void> updateConsent() async {
    calls.add('update');
    if (failConsent) throw StateError('offline');
    await consentWait?.future;
  }

  @override
  Future<void> collectConsent() async => calls.add('collect');

  @override
  Future<bool> canRequestAds() async {
    calls.add('allowed');
    return allowed;
  }

  @override
  Future<bool> requiresPrivacyOptions() async {
    calls.add('privacyRequired');
    return privacyRequired;
  }

  @override
  Future<void> showPrivacyOptions() async {
    calls.add('showPrivacy');
    if (failPrivacy) throw StateError('offline');
    await privacyWait?.future;
  }

  @override
  Future<void> initializeAds() async {
    calls.add('initializeAds');
    if (failSdk) throw StateError('SDK unavailable');
  }
}

void main() {
  AdMobService createService(FakeAdMobGateway gateway) =>
      AdMobService(gateway: gateway, supported: true, usesLiveAds: true);

  test('live ads wait for consent and SDK initialization', () async {
    final gateway = FakeAdMobGateway()..consentWait = Completer<void>();
    final service = createService(gateway);
    final pending = service.initialize();
    expect(service.adsReady.value, isFalse);
    expect(gateway.calls, ['update']);
    gateway.consentWait!.complete();
    await pending;
    expect(gateway.calls, [
      'update',
      'collect',
      'privacyRequired',
      'allowed',
      'initializeAds',
    ]);
    expect(service.adsReady.value, isTrue);
    expect(service.privacyOptionsRequired.value, isTrue);
  });

  test('repeated startup does not duplicate consent or SDK work', () async {
    final gateway = FakeAdMobGateway();
    final service = createService(gateway);
    await Future.wait([service.initialize(), service.initialize()]);
    await service.initialize();
    expect(gateway.calls.where((call) => call == 'update').length, 1);
    expect(gateway.calls.where((call) => call == 'initializeAds').length, 1);
  });

  test('unresolved consent prevents SDK initialization and ads', () async {
    final gateway = FakeAdMobGateway()..allowed = false;
    final service = createService(gateway);
    await service.initialize();
    expect(service.adsReady.value, isFalse);
    expect(gateway.calls, isNot(contains('initializeAds')));
  });

  test('consent errors never grant permission themselves', () async {
    for (final previousConsent in [false, true]) {
      final gateway = FakeAdMobGateway()
        ..failConsent = true
        ..allowed = previousConsent;
      final service = createService(gateway);
      await service.initialize();
      expect(service.adsReady.value, previousConsent);
      expect(gateway.calls, isNot(contains('collect')));
    }
  });

  test('test ads bypass live consent but still wait for SDK', () async {
    final gateway = FakeAdMobGateway();
    final service = AdMobService(
      gateway: gateway,
      supported: true,
      usesLiveAds: false,
    );
    await service.initialize();
    expect(gateway.calls, ['initializeAds']);
    expect(service.adsReady.value, isTrue);
    expect(service.privacyOptionsRequired.value, isFalse);
  });

  test('unsupported platforms never touch native plugins', () async {
    final gateway = FakeAdMobGateway();
    final service = AdMobService(gateway: gateway, supported: false);
    await service.initialize();
    expect(gateway.calls, isEmpty);
    expect(service.adsReady.value, isFalse);
  });

  test('SDK errors leave ad placements hidden', () async {
    final gateway = FakeAdMobGateway()..failSdk = true;
    final service = createService(gateway);
    await service.initialize();
    expect(service.adsReady.value, isFalse);
  });

  test('privacy changes suspend ads and respect updated consent', () async {
    final gateway = FakeAdMobGateway()..privacyWait = Completer<void>();
    final service = createService(gateway);
    await service.initialize();
    final pending = service.showPrivacyOptions();
    expect(service.adsReady.value, isFalse);
    expect(await service.showPrivacyOptions(), isFalse);
    gateway.allowed = false;
    gateway.privacyWait!.complete();
    expect(await pending, isTrue);
    expect(service.adsReady.value, isFalse);
    gateway.allowed = true;
    expect(await service.showPrivacyOptions(), isTrue);
    expect(service.adsReady.value, isTrue);
    expect(gateway.calls.where((call) => call == 'initializeAds').length, 1);
  });

  test('privacy form errors are handled and consent is rechecked', () async {
    final gateway = FakeAdMobGateway();
    final service = createService(gateway);
    await service.initialize();
    gateway.failPrivacy = true;
    gateway.allowed = false;
    expect(await service.showPrivacyOptions(), isFalse);
    expect(service.adsReady.value, isFalse);
  });

  test('privacy options are inaccessible when not required', () async {
    final gateway = FakeAdMobGateway()..privacyRequired = false;
    final service = createService(gateway);
    await service.initialize();
    expect(await service.showPrivacyOptions(), isFalse);
    expect(gateway.calls, isNot(contains('showPrivacy')));
  });
}
