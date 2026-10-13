import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/push_target.dart';
import '../screens/chat_screen.dart';
import '../screens/my_ads_screen.dart';
import '../screens/wallet_screen.dart';
import '../widgets/app_notice.dart';
import '../widgets/paywall_modal.dart';
import '../screens/post_ad_screen.dart';
import 'api_service.dart';
import 'android_notifications.dart';
import 'auth_service.dart';
import 'chat_unread_service.dart';
import 'my_ads_updates_service.dart';

@pragma('vm:entry-point')
Future<void> ojioBackgroundMessage(RemoteMessage message) async {
  // The native SDK displays background notifications. Never trust a push to
  // change payment state or account benefits; those are fetched from the API.
  await Firebase.initializeApp();
}

class PushNotificationsService with WidgetsBindingObserver {
  PushNotificationsService._();
  static final instance = PushNotificationsService._();
  final navigatorKey = GlobalKey<NavigatorState>();
  bool _initialized = false;
  bool _appReady = false;
  Map<String, dynamic>? _pending;
  Future<void> _operations = Future<void>.value();
  Timer? _retry;
  final Set<String> _received = {};
  final _pendingForeground = SessionPushBuffer<RemoteMessage>();
  final _androidNotifications = AndroidNotifications();

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (!_supported || _initialized) return;
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
      FirebaseMessaging.onBackgroundMessage(ojioBackgroundMessage);
      FirebaseMessaging.onMessage.listen(_foreground);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _tap(message.data),
      );
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) => sync(),
        onError: (_) => _scheduleRetry(),
      );
      AuthService().sessionChanges.addListener(_sessionChanged);
      AuthService().onLogout = _logout;
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
      await _androidNotifications.initialize(_tap);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pending = initial.data;
    } catch (_) {
      debugPrint(
        'Push initialization unavailable. Check Firebase configuration.',
      );
    }
  }

  void appReady() {
    _appReady = true;
    unawaited(sync());
    for (final message in _pendingForeground.takeForSession(
      AuthService().token,
    )) {
      unawaited(_foreground(message));
    }
    final pending = _pending;
    _pending = null;
    if (pending != null) unawaited(_tap(pending));
  }

  void _sessionChanged() {
    unawaited(sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(sync());
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.catchError((Object _) {});
    return next;
  }

  Future<String> _deviceKey() async {
    final prefs = await SharedPreferences.getInstance();
    var key = prefs.getString('push_device_key');
    if (key == null) {
      final random = Random.secure();
      key = List.generate(
        32,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await prefs.setString('push_device_key', key);
    }
    return key;
  }

  Future<void> sync() async {
    if (!_initialized || !AuthService().isAuthenticated) return;
    await _enqueue(() async {
      final session = AuthService().token;
      if (session == null || !AuthService().isAuthenticated) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        // Request once. A declined system permission must not be prompted
        // repeatedly on every resume; the user can change Android app settings.
        final asked = prefs.getBool('push_permission_requested') ?? false;
        var settings = await FirebaseMessaging.instance
            .getNotificationSettings();
        if (!asked) {
          await prefs.setBool('push_permission_requested', true);
          settings = await FirebaseMessaging.instance.requestPermission();
        }
        if (session != AuthService().token) return;
        final granted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        final key = await _deviceKey();
        if (!granted) {
          await ApiService().unregisterPushDevice(key, session);
          await FirebaseMessaging.instance.setAutoInitEnabled(false);
          await FirebaseMessaging.instance.deleteToken();
          return;
        }
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
        final token = await FirebaseMessaging.instance.getToken();
        if (token == null || session != AuthService().token) return;
        await ApiService().registerPushDevice(
          key,
          token,
          session,
          chatEnabled: prefs.getBool('pref_chat_notif') ?? true,
          marketingEnabled: prefs.getBool('pref_market_notif') ?? false,
        );
        _retry?.cancel();
      } catch (_) {
        // Do not log device tokens or block sign-in when the API is unavailable.
        debugPrint('Push registration pending; it will retry.');
        _scheduleRetry();
      }
    });
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (AuthService().isAuthenticated) {
      _retry = Timer(const Duration(seconds: 30), () => unawaited(sync()));
    }
  }

  Future<void> _logout(String? oldSession) async {
    _appReady = false;
    _pending = null;
    _received.clear();
    _pendingForeground.clear();
    _retry?.cancel();
    final clearing = _androidNotifications.clear();
    if (!_initialized) {
      await clearing;
      return;
    }
    // Queue logout before a subsequent login can queue device registration.
    // Clearing native notifications must not delay that ordering.
    await _enqueue(() async {
      await clearing;
      try {
        if (oldSession != null) {
          await ApiService().unregisterPushDevice(
            await _deviceKey(),
            oldSession,
          );
        }
      } catch (_) {
        // Token deletion below also invalidates old registrations when offline.
      }
      try {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    });
  }

  Future<void> _foreground(RemoteMessage message) async {
    if (!AuthService().isAuthenticated) return;
    if (!_appReady) {
      // A welcome can arrive while the mandatory contact setup is still open.
      if (PushTarget.parse(message.data, AuthService().currentUserId) != null) {
        _pendingForeground.add(AuthService().token!, message);
      }
      return;
    }
    final data = message.data;
    final target = PushTarget.parse(data, AuthService().currentUserId);
    if (target?.type == 'chat') {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('pref_chat_notif') ?? true)) return;
      if (target?.recipientId != AuthService().currentUserId) return;
    }
    if (target?.type == 'coupon' || target?.type == 'post_reminder') {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('pref_market_notif') ?? false)) return;
      if (target?.recipientId != AuthService().currentUserId) return;
    }
    // Console test notifications have no account-specific data.
    if (target == null && data.isNotEmpty) return;
    final id = message.messageId ?? data['event_id']?.toString();
    if (id != null && !_received.add(id)) return;
    if (_received.length > 100) _received.remove(_received.first);
    unawaited(ChatUnreadService.instance.refresh());
    unawaited(MyAdsUpdatesService.instance.refresh());
    final navigator = navigatorKey.currentState;
    if (navigator == null || navigator.overlay == null) return;
    final noticeContext = navigator.context;
    if (!noticeContext.mounted) return;
    final title = message.notification?.title ?? 'OJIO';
    final body = message.notification?.body ?? 'You have a new update.';
    final session = AuthService().token;
    final shown = await _androidNotifications.show(
      title: title,
      body: body,
      eventId: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      data: data,
    );
    if (shown || session != AuthService().token || !noticeContext.mounted) {
      return;
    }
    AppNotice.show(
      noticeContext,
      SnackBar(
        content: InkWell(
          onTap: target == null || target.type == 'test'
              ? null
              : () => _tap(data),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(body),
            ],
          ),
        ),
      ),
      overlay: navigator.overlay,
    );
  }

  Future<void> _tap(Map<String, dynamic> data) async {
    if (!_appReady) {
      _pending = Map<String, dynamic>.from(data);
      return;
    }
    final auth = AuthService();
    final target = PushTarget.parse(data, auth.currentUserId);
    final session = auth.token;
    if (target == null || !auth.isAuthenticated) return;
    if (target.type == 'test') return;
    if (target.type == 'coupon' || target.type == 'post_reminder') {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('pref_market_notif') ?? false) ||
          session != auth.token) {
        return;
      }
    }
    if (target.type == 'welcome') {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    if (target.type == 'coupon') {
      final context = navigatorKey.currentState?.context;
      if (context != null && context.mounted) {
        await PaywallModal.show(
          context,
          onPaymentSuccess: () {
            if (session == auth.token) {
              unawaited(ApiService().fetchUserProfile());
            }
          },
        );
      }
      return;
    }
    Widget screen;
    try {
      if (target.type == 'chat') {
        // The authenticated API checks ownership; never navigate on push IDs alone.
        final threads = await ApiService().fetchChatThreads(throwOnError: true);
        if (session != auth.token || !_appReady) return;
        final matches = threads.where((thread) => thread.id == target.threadId);
        if (matches.isEmpty) return;
        final thread = matches.first;
        final other = thread.buyerId == auth.currentUserId
            ? thread.seller
            : thread.buyer;
        screen = ChatConversationScreen(
          threadId: thread.id,
          listingId: thread.listingId,
          otherUserName: other?['name']?.toString() ?? 'Chat',
          itemTitle: thread.listing?.title ?? 'Listing',
        );
      } else if (target.type == 'ad_status') {
        screen = const MyAdsScreen();
      } else if (target.type == 'post_reminder') {
        screen = const PostAdScreen();
      } else {
        screen = const WalletScreen();
      }
      if (session != auth.token || !_appReady) return;
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => screen),
      );
    } catch (_) {
      debugPrint('Notification destination unavailable; retry from the app.');
    }
  }
}
