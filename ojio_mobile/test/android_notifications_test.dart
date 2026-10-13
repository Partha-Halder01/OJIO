import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/services/android_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = AndroidNotifications();
  tearDown(() {
    messenger.setMockMethodCallHandler(AndroidNotifications.channel, null);
    AndroidNotifications.channel.setMethodCallHandler(null);
  });

  test('foreground notifications include the correct tap payload', () async {
    messenger.setMockMethodCallHandler(AndroidNotifications.channel, (
      call,
    ) async {
      expect(call.method, 'show');
      expect(call.arguments, {
        'title': 'OJIO',
        'body': 'New message',
        'eventId': 'event-1',
        'data': {'type': 'chat', 'recipient_user_id': '7', 'thread_id': '12'},
      });
      return true;
    });
    expect(
      await service.show(
        title: 'OJIO',
        body: 'New message',
        eventId: 'event-1',
        data: {'type': 'chat', 'recipient_user_id': '7', 'thread_id': '12'},
      ),
      isTrue,
    );
  });

  test(
    'denied permissions and unavailable bridge allow in-app fallback',
    () async {
      for (final unavailable in [false, true]) {
        messenger.setMockMethodCallHandler(AndroidNotifications.channel, (
          _,
        ) async {
          if (unavailable) throw PlatformException(code: 'unavailable');
          return false;
        });
        expect(
          await service.show(
            title: 'OJIO',
            body: 'Update',
            eventId: '1',
            data: {},
          ),
          isFalse,
        );
      }
    },
  );

  test(
    'cold-start tap is forwarded and logout clears system notifications',
    () async {
      final calls = <String>[];
      final received = <Map<String, dynamic>>[];
      messenger.setMockMethodCallHandler(AndroidNotifications.channel, (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'getInitialNotification') {
          return {'type': 'payment', 'recipient_user_id': '7'};
        }
        return null;
      });
      await service.initialize((data) async => received.add(data));
      expect(received.single, {'type': 'payment', 'recipient_user_id': '7'});
      await service.clear();
      expect(calls, ['getInitialNotification', 'clear']);
    },
  );
}
