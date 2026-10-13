/// Short-lived startup notifications never survive a login-session change.
class SessionPushBuffer<T> {
  final List<(String, T)> _messages = [];

  void add(String session, T message) {
    _messages.add((session, message));
    if (_messages.length > 10) _messages.removeAt(0);
  }

  List<T> takeForSession(String? session) {
    final result = [
      for (final (owner, message) in _messages)
        if (owner == session) message,
    ];
    clear();
    return result;
  }

  void clear() => _messages.clear();
}

class PushTarget {
  const PushTarget(this.type, this.recipientId, {this.threadId});
  final String type;
  final int recipientId;
  final int? threadId;

  static PushTarget? parse(Map<String, dynamic> data, int currentUserId) {
    final recipient = int.tryParse('${data['recipient_user_id']}');
    final type = data['type'];
    if (currentUserId <= 0 || recipient != currentUserId) return null;
    if (type == 'chat') {
      final thread = int.tryParse('${data['thread_id']}');
      if (thread == null || thread <= 0) return null;
      return PushTarget('chat', recipient!, threadId: thread);
    }
    if (type == 'coupon') {
      final coupon = int.tryParse('${data['coupon_id']}');
      if (coupon == null || coupon <= 0) return null;
      return PushTarget('coupon', recipient!);
    }
    if (type == 'ad_status' ||
        type == 'payment' ||
        type == 'test' ||
        type == 'welcome' ||
        type == 'post_reminder') {
      return PushTarget(type as String, recipient!);
    }
    return null;
  }
}
