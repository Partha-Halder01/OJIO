import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../services/push_notifications_service.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _chatNotifications = true;
  bool _recommendationAlerts = true;
  bool _marketingEmails = false;
  bool _priceDrops = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _chatNotifications = prefs.getBool('pref_chat_notif') ?? true;
      _recommendationAlerts = prefs.getBool('pref_rec_notif') ?? true;
      _marketingEmails = prefs.getBool('pref_market_notif') ?? false;
      _priceDrops = prefs.getBool('pref_price_notif') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    await PushNotificationsService.instance.sync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildHeader('MESSAGES & CHATS'),
          _buildSwitchTile(
            title: 'Chat Notifications',
            subtitle: 'Get instant alerts when a buyer or seller messages you',
            value: _chatNotifications,
            onChanged: (val) {
              setState(() => _chatNotifications = val);
              _saveSetting('pref_chat_notif', val);
            },
          ),
          const SizedBox(height: 16),
          _buildHeader('ACTIVITY & RECOMMENDATIONS'),
          _buildSwitchTile(
            title: 'Price Drop Alerts',
            subtitle: 'Notify me when items in my wishlist change price',
            value: _priceDrops,
            onChanged: (val) {
              setState(() => _priceDrops = val);
              _saveSetting('pref_price_notif', val);
            },
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildSwitchTile(
            title: 'Recommended Ads',
            subtitle:
                'Personalized product suggestions tailored to your searches',
            value: _recommendationAlerts,
            onChanged: (val) {
              setState(() => _recommendationAlerts = val);
              _saveSetting('pref_rec_notif', val);
            },
          ),
          const SizedBox(height: 16),
          _buildHeader('MARKETING & UPDATES'),
          _buildSwitchTile(
            title: 'Promotional Offers',
            subtitle:
                'Coupon offers and occasional reminders when free posting quota is available',
            value: _marketingEmails,
            onChanged: (val) {
              setState(() => _marketingEmails = val);
              _saveSetting('pref_market_notif', val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      color: Colors.white,
      child: SwitchListTile.adaptive(
        activeColor: const Color(0xFF087CF5),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: const Color(0xFF0D1B2A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
    );
  }
}
