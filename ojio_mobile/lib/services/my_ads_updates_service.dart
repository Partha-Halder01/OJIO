import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'auth_service.dart';

class MyAdsUpdatesService extends ValueNotifier<bool> {
  static final instance = MyAdsUpdatesService();
  MyAdsUpdatesService({ApiService? api})
    : _api = api ?? ApiService(),
      super(false);
  final ApiService _api;
  String? _token;
  int _revision = 0;
  bool _fetching = false;
  bool _acknowledging = false;

  void reset() {
    _revision++;
    _token = AuthService().token;
    value = false;
  }

  Future<void> refresh() async {
    if (_token != AuthService().token || !AuthService().isAuthenticated)
      reset();
    if (!AuthService().isAuthenticated || _fetching || _acknowledging) return;
    final token = _token;
    final revision = _revision;
    _fetching = true;
    try {
      final unread = await _api.fetchAdUpdates();
      if (token == AuthService().token && revision == _revision) value = unread;
    } catch (_) {
      // Keep the last confirmed state while offline.
    } finally {
      _fetching = false;
    }
  }

  Future<void> acknowledge(
    List<Map<String, dynamic>> updates,
    String? token,
  ) async {
    if (token != AuthService().token || !AuthService().isAuthenticated) return;
    final revision = ++_revision;
    _acknowledging = true;
    try {
      final unread = await _api.readAdUpdates(updates);
      if (token == AuthService().token && revision == _revision) value = unread;
    } catch (_) {
      // Do not clear the dot unless the server confirms acknowledgement.
    } finally {
      _acknowledging = false;
    }
  }
}
