class PremiumStatus {
  static bool active(bool enabled, String? until, DateTime now) {
    if (!enabled) return false;
    // A null expiry is reserved for server-confirmed non-expiring packages.
    if (until == null) return true;
    final expiry = DateTime.tryParse(until);
    return expiry != null && expiry.isAfter(now);
  }
}
