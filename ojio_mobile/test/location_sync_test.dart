import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ojio_mobile/core/marketplace_location.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/main.dart' show ProfileScreen;
import 'package:ojio_mobile/services/api_service.dart';
import 'package:ojio_mobile/services/auth_service.dart';

final profile = <String, dynamic>{
  'id': 1,
  'name': 'Seller',
  'email': 'seller@example.com',
  'phone': '9876543210',
  'city': 'Kolkata',
  'state': 'West Bengal',
  'country': 'India',
};

ApiService locationApi(List<Map<String, dynamic>> calls) => ApiService(
  client: MockClient((request) async {
    expect(request.url.path.endsWith('/user/location'), true);
    final payload = Map<String, dynamic>.from(jsonDecode(request.body));
    calls.add(payload);
    return http.Response(
      jsonEncode({
        'status': 'success',
        'user': {...profile, ...payload},
      }),
      200,
    );
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService().token = 'seller-token';
    AuthService().currentUser = UserModel.fromJson(profile);
    AuthService().location.value = null;
  });
  tearDown(() {
    AuthService().token = null;
    AuthService().currentUser = null;
    AuthService().location.value = null;
  });

  test(
    'manual and detected locations update profile, shared state and persistent coordinates',
    () async {
      final calls = <Map<String, dynamic>>[];
      final api = locationApi(calls);
      await AuthService().selectLocation(
        MarketplaceLocation.forCity('Hyderabad'),
        api: api,
      );
      expect(AuthService().currentUser?.city, 'Hyderabad');
      expect(AuthService().location.value?.city, 'Hyderabad');
      expect(AuthService().location.value?.latitude, 17.385);
      await AuthService().selectLocation(
        const MarketplaceLocation(
          'Hyderabad',
          latitude: 17.42,
          longitude: 78.44,
          state: 'Telangana',
          country: 'India',
        ),
        api: api,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('marketplace_latitude'), 17.42);
      expect(prefs.getDouble('marketplace_longitude'), 78.44);
      expect(calls.last['latitude'], 17.42);
      expect(AuthService().currentUser?.latitude, 17.42);
      await AuthService().selectLocation(
        MarketplaceLocation.forCity('Custom town'),
        api: api,
      );
      expect(prefs.getDouble('marketplace_latitude'), isNull);
      expect(AuthService().location.value?.longitude, isNull);
    },
  );

  test(
    'restoring an existing installation repairs the Home/Profile city mismatch',
    () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'seller-token',
        'marketplace_city': 'Hyderabad',
        'marketplace_latitude': 17.42,
        'marketplace_longitude': 78.44,
      });
      final calls = <Map<String, dynamic>>[];
      await AuthService().restoreLocation(api: locationApi(calls));
      expect(AuthService().currentUser?.city, 'Hyderabad');
      expect(AuthService().location.value?.latitude, 17.42);
      expect(calls.single['city'], 'Hyderabad');
      AuthService().location.value = null;
      await AuthService().init();
      await AuthService().restoreLocation(api: locationApi(calls));
      expect(AuthService().currentUser?.city, 'Hyderabad');
      expect(AuthService().location.value?.latitude, 17.42);
      expect(calls.length, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('auth_user')!)['city'], 'Hyderabad');
    },
  );

  test(
    'cached location from another account cannot overwrite the signed-in profile',
    () async {
      SharedPreferences.setMockInitialValues({
        'marketplace_city': 'Hyderabad',
        'marketplace_user_id': 2,
        'marketplace_latitude': 17.42,
        'marketplace_longitude': 78.44,
      });
      final calls = <Map<String, dynamic>>[];
      await AuthService().restoreLocation(api: locationApi(calls));
      expect(AuthService().location.value?.city, 'Kolkata');
      expect(AuthService().location.value?.latitude, 22.5726);
      expect(calls, isEmpty);
    },
  );

  test(
    'failed location save preserves confirmed profile and coordinates',
    () async {
      await AuthService().updateUser(profile);
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response('{"message":"Unavailable"}', 503),
        ),
      );
      await expectLater(
        AuthService().selectLocation(
          MarketplaceLocation.forCity('Pune'),
          api: api,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(AuthService().location.value?.city, 'Kolkata');
      expect(AuthService().currentUser?.city, 'Kolkata');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('marketplace_latitude'), 22.5726);
    },
  );

  test(
    'new sign-in uses that account location and sign-out clears its cached location',
    () async {
      await AuthService().setAuth('other-token', {
        ...profile,
        'id': 2,
        'city': 'Pune',
        'state': 'Maharashtra',
      });
      expect(AuthService().location.value?.city, 'Pune');
      await AuthService().logout();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('marketplace_city'), isNull);
      expect(AuthService().location.value, isNull);
    },
  );

  test(
    'identity edits do not submit an old city or replace detected coordinates',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect(jsonDecode(request.body), {
            'name': 'New name',
            'phone': '9876543210',
          });
          return http.Response(
            jsonEncode({
              'status': 'success',
              'user': {
                ...profile,
                'name': 'New name',
                'city': 'Hyderabad',
                'state': 'Telangana',
                'latitude': 17.42,
                'longitude': 78.44,
              },
            }),
            200,
          );
        }),
      );
      final result = await api.updateProfileDetails('New name', '9876543210');
      await AuthService().updateUser(result['user']);
      expect(AuthService().location.value?.city, 'Hyderabad');
      expect(AuthService().location.value?.latitude, 17.42);
    },
  );

  testWidgets('Profile reflects shared city changes while kept open', (
    tester,
  ) async {
    await AuthService().updateUser(profile);
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    expect(
      find.textContaining('9876543210').evaluate().single.widget.toString(),
      contains('Kolkata'),
    );
    await tester.runAsync(
      () => AuthService().selectLocation(
        MarketplaceLocation.forCity('Hyderabad'),
        api: locationApi([]),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('9876543210').evaluate().single.widget.toString(),
      contains('Hyderabad'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
