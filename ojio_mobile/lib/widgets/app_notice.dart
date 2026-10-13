import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class AppNotice {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    SnackBar notice, {
    OverlayState? overlay,
  }) {
    if (!context.mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    dismiss();
    final noticeOverlay = overlay ?? Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 16,
        right: 16,
        child: Material(
          key: const Key('app-top-notice'),
          color: notice.backgroundColor ?? AppColors.darkBrand,
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              child: notice.content,
            ),
          ),
        ),
      ),
    );
    noticeOverlay.insert(_entry!);
    _timer = Timer(const Duration(seconds: 3), dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class AppNoticeObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppNotice.dismiss();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppNotice.dismiss();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    AppNotice.dismiss();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppNotice.dismiss();
  }
}
