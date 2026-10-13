import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../models/models.dart';

class ChatUnreadService extends ValueNotifier<int> {
  static final instance = ChatUnreadService._();
  ChatUnreadService._() : super(0);
  final Map<int, int> _counts = {};
  int _revision = 0;
  bool _fetching = false;

  void reset() {
    _revision++;
    _counts.clear();
    value = 0;
  }

  void clearThread(int id) {
    if (_counts[id] == 0) return;
    _revision++;
    _counts[id] = 0;
    value = _counts.values.fold(0, (total, count) => total + count);
  }

  Future<void> refresh() async {
    if (!AuthService().isAuthenticated) {
      reset();
      return;
    }
    if (_fetching) return;
    final token = AuthService().token;
    final revision = _revision;
    _fetching = true;
    try {
      final threads = await ApiService().fetchChatThreads(throwOnError: true);
      if (token != AuthService().token || revision != _revision) return;
      setThreads(threads);
    } catch (_) {
      // Keep the last confirmed count during temporary network failures.
    } finally {
      _fetching = false;
    }
  }

  @visibleForTesting
  void setThreads(List<ChatThreadModel> threads) {
    _counts.clear();
    for (final thread in threads) {
      _counts[thread.id] = thread.unreadCount;
    }
    value = _counts.values.fold(0, (total, count) => total + count);
  }
}
