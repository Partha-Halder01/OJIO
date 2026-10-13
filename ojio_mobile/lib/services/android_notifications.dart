import 'package:flutter/services.dart';

/// Foreground FCM messages need to be posted to Android explicitly. Background
/// messages are displayed by Firebase, so they must not be posted a second time.
class AndroidNotifications {
  static const channel = MethodChannel('ojio/push_notifications');

  Future<void> initialize(
    Future<void> Function(Map<String, dynamic>) onTap,
  ) async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTap' && call.arguments is Map) {
        await onTap(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
    try {
      final initial = await channel.invokeMapMethod<String, dynamic>(
        'getInitialNotification',
      );
      if (initial != null) await onTap(initial);
    } on PlatformException {
      // Older installed builds can still use the in-app notification fallback.
    } on MissingPluginException {
      // No Android bridge on other platforms or older builds.
    }
  }

  Future<bool> show({
    required String title,
    required String body,
    required String eventId,
    required Map<String, dynamic> data,
  }) async {
    try {
      return await channel.invokeMethod<bool>('show', {
            'title': title,
            'body': body,
            'eventId': eventId,
            'data': data,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> clear() async {
    try {
      await channel.invokeMethod<void>('clear');
    } on PlatformException {
      // Logout must not depend on native notification availability.
    } on MissingPluginException {
      // Older builds have no bridge.
    }
  }
}
