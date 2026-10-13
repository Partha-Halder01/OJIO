import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/paywall_modal.dart';
import 'about_ojio_screen.dart';
import 'change_password_screen.dart';
import 'city_location_screen.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'login_screen.dart';
import 'notifications_settings_screen.dart';
import 'privacy_safety_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final ApiService _api = ApiService();
  int _myAdsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _api.fetchUserProfile();
      final myAds = await _api.fetchMyListings();
      if (mounted) {
        setState(() {
          _myAdsCount = myAds.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final name = user?.name.isNotEmpty == true ? user!.name : 'OJIO User';
    final emailOrPhone = (user?.phone != null && user!.phone!.isNotEmpty)
        ? user.phone!
        : (user?.email ?? 'No contact added');
    final city = user?.city ?? 'Location not set';

    final initials = name.trim().isNotEmpty
        ? name
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join('')
              .toUpperCase()
        : 'U';

    final freeAdsPosted = user?.freeAdsUsed ?? _myAdsCount;
    final freeAdsLimit = user?.freeAdsLimit ?? 2;
    final freeAdsRemaining = (freeAdsLimit - freeAdsPosted).clamp(
      0,
      freeAdsLimit,
    );
    final hasDiamond = user?.hasDiamondBadge ?? false;
    final paidQuota = user?.paidAdsQuota ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Account',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.textMain,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initials,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            if (hasDiamond) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  border: Border.all(
                                    color: const Color(0xFF93C5FD),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '💎 PRO',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF087CF5),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          emailOrPhone,
                          style: GoogleFonts.outfit(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'City: $city',
                          style: GoogleFonts.outfit(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ).then((_) => setState(() {}));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Monetization Quota & Premium Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: hasDiamond
                      ? const LinearGradient(
                          colors: [Color(0xFF087CF5), Color(0xFF034EA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: hasDiamond
                          ? const Color(0xFF087CF5).withAlpha(100)
                          : Colors.black.withAlpha(50),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              hasDiamond
                                  ? '💎 Diamond Member'
                                  : 'Free Listing Allowance',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            PaywallModal.show(
                              context,
                              onPaymentSuccess: () {
                                _loadData();
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              hasDiamond ? 'Extend' : 'Upgrade',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF087CF5),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (hasDiamond) ...[
                      Text(
                        'Unlimited Ad Postings Active',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All your listings showcase the 💎 Diamond Seller badge.',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ] else ...[
                      Text(
                        paidQuota > 0
                            ? '$paidQuota Paid Ads Quota Available'
                            : '$freeAdsPosted of $freeAdsLimit Free Ads Used',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        freeAdsRemaining > 0
                            ? '$freeAdsRemaining free ads remaining. Quota restores 30 days after it is used.'
                            : user?.freeQuotaResetsAt != null
                            ? 'Free quota restores on ${DateFormat.yMMMd().format(user!.freeQuotaResetsAt!.toLocal())}. Premium lets you post now.'
                            : 'No free posts available. Choose a premium package to post.',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: freeAdsLimit == 0
                              ? 1
                              : (freeAdsPosted / freeAdsLimit).clamp(0.0, 1.0),
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF087CF5),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Menu Options
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildMenuItem(
                    Icons.person_outline,
                    'Edit Profile Information',
                    'Update',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ).then((_) => setState(() {}));
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuItem(
                    Icons.lock_reset_outlined,
                    'Change Account Password',
                    'Security',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuItem(
                    Icons.location_on_outlined,
                    'Location / City Selector',
                    city,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CityLocationScreen(),
                        ),
                      ).then((_) => setState(() {}));
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuItem(
                    Icons.diamond_outlined,
                    'Premium Packages & Badges',
                    hasDiamond ? 'Active 💎' : '₹49+',
                    onTap: () {
                      PaywallModal.show(
                        context,
                        onPaymentSuccess: () {
                          _loadData();
                        },
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuItem(
                    Icons.notifications_none,
                    'Notifications & Alerts',
                    'Active',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuItem(
                    Icons.shield_outlined,
                    'Safety & Privacy Settings',
                    'Verified',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacySafetyScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuItem(
                    Icons.help_outline,
                    'Help & Customer Support',
                    '24x7',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuItem(
                    Icons.info_outline,
                    'About OJIO Classifieds',
                    'v1.0.0',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AboutOjioScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                    title: Text(
                      'Log Out',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.redAccent,
                      ),
                    ),
                    onTap: () async {
                      await AuthService().logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String trailingText, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trailingText,
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
