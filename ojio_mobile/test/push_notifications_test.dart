import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ojio_mobile/core/push_target.dart';
import 'package:ojio_mobile/services/api_service.dart';
import 'package:ojio_mobile/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'startup notification buffer only releases the matching session once',
    () {
      final buffer = SessionPushBuffer<String>();
      buffer.add('first', 'Old welcome');
      buffer.add('second', 'New welcome');
      expect(buffer.takeForSession('second'), ['New welcome']);
      expect(buffer.takeForSession('first'), isEmpty);
      expect(buffer.takeForSession('second'), isEmpty);
    },
  );
  test('startup notification buffer is bounded and clears on logout', () {
    final buffer = SessionPushBuffer<int>();
    for (var i = 0; i < 15; i++) {
      buffer.add('session', i);
    }
    expect(buffer.takeForSession('session'), List.generate(10, (i) => i + 5));
    buffer.add('session', 99);
    buffer.clear();
    expect(buffer.takeForSession('session'), isEmpty);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService().token = 'current-session';
  });

  test('chat targets are validated and account scoped', () {
    final data = {'type': 'chat', 'recipient_user_id': '7', 'thread_id': '12'};
    expect(PushTarget.parse(data, 7)?.threadId, 12);
    expect(PushTarget.parse(data, 8), isNull);
    expect(PushTarget.parse(data, 0), isNull);
    expect(PushTarget.parse({...data, 'thread_id': '-1'}, 7), isNull);
    expect(
      PushTarget.parse({...data, 'thread_id': 'https://evil.test'}, 7),
      isNull,
    );
    expect(
      PushTarget.parse({...data, 'recipient_user_id': 'invalid'}, 7),
      isNull,
    );
  });

  test('only known activity destinations are accepted', () {
    for (final kind in [
      'ad_status',
      'payment',
      'test',
      'welcome',
      'post_reminder',
    ]) {
      expect(
        PushTarget.parse({'type': kind, 'recipient_user_id': '7'}, 7)?.type,
        kind,
      );
      expect(
        PushTarget.parse({'type': kind, 'recipient_user_id': '8'}, 7),
        isNull,
      );
    }
    expect(
      PushTarget.parse({'type': '/admin', 'recipient_user_id': '7'}, 7),
      isNull,
    );
    expect(PushTarget.parse({}, 7), isNull);
  });

  test(
    'device registration uses the captured session and preferences',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/user/push-device');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer captured-session');
        expect(jsonDecode(request.body), {
          'device_key': 'installation-secret',
          'token': 'device-token',
          'chat_enabled': false,
          'marketing_enabled': true,
        });
        return http.Response('{"status":"success"}', 200);
      });
      await ApiService(client: client).registerPushDevice(
        'installation-secret',
        'device-token',
        'captured-session',
        chatEnabled: false,
        marketingEnabled: true,
      );
      expect(AuthService().token, 'current-session');
    },
  );

  test('push failures do not log out a newer account', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response('{"message":"Unauthenticated."}', 401),
      ),
    );
    await expectLater(
      api.registerPushDevice('key', 'token', 'old-session', chatEnabled: true),
      throwsA(isA<ApiException>()),
    );
    expect(AuthService().token, 'current-session');
    await api.unregisterPushDevice('key', 'old-session');
    expect(AuthService().token, 'current-session');
  });

  test('coupon targets require a valid coupon and the right recipient', () {
    final data = {
      'type': 'coupon',
      'recipient_user_id': '7',
      'coupon_id': '12',
    };
    expect(PushTarget.parse(data, 7)?.type, 'coupon');
    expect(PushTarget.parse(data, 8), isNull);
    expect(PushTarget.parse({...data, 'coupon_id': '0'}, 7), isNull);
    expect(PushTarget.parse({...data, 'coupon_id': '/admin'}, 7), isNull);
  });

  test('promotional registration defaults to opted out', () async {
    final api = ApiService(
      client: MockClient((request) async {
        expect(jsonDecode(request.body)['marketing_enabled'], false);
        return http.Response('{"status":"success"}', 200);
      }),
    );
    await api.registerPushDevice('key', 'token', 'session', chatEnabled: true);
  });

  test(
    'logout unregistration uses the old session, not the current session',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.headers['Authorization'], 'Bearer old-session');
          expect(jsonDecode(request.body), {'device_key': 'key'});
          return http.Response('{"status":"success"}', 200);
        }),
      );
      await api.unregisterPushDevice('key', 'old-session');
    },
  );

  test(
    'server failure during unregister is reported for token invalidation fallback',
    () async {
      final api = ApiService(
        client: MockClient((_) async => http.Response('{}', 503)),
      );
      await expectLater(
        api.unregisterPushDevice('key', 'old-session'),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
