import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';



class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {
        'icon': Icons.chat_bubble_rounded,
        'color': AppColors.primary,
        'title': 'New message from Rahul Kumar',
        'desc': 'Can you do ?48,000 for quick pickup today?',
        'time': '5m ago',
      },
      {
        'icon': Icons.verified_rounded,
        'color': AppColors.success,
        'title': 'Your Ad is Approved & Live',
        'desc': 'Royal Enfield Classic 350 has been approved by admin.',
        'time': '1h ago',
      },
      {
        'icon': Icons.payment_rounded,
        'color': AppColors.primary,
        'title': 'Payment Successful',
        'desc': '?49 paid for 30-day listing boost.',
        'time': 'Yesterday',
      },
      {
        'icon': Icons.location_on_rounded,
        'color': AppColors.warning,
        'title': 'New Listing Near You in Kolkata',
        'desc': 'Honda Activa 6G posted just 2.1 km away.',
        'time': '2 days ago',
      },
      {
        'icon': Icons.alarm_rounded,
        'color': AppColors.error,
        'title': 'Your Ad Expires Soon',
        'desc': 'Renew or mark iPhone 15 as sold to keep clean logs.',
        'time': '3 days ago',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.textMain,
          ),
        ),
        backgroundColor: AppColors.card,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textMain),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: notifications.length,
        separatorBuilder: (_, __dummy) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final item = notifications[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            tileColor: AppColors.card,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (item['color'] as Color).withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
            ),
            title: Text(
              item['title'] as String,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textMain),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  item['desc'] as String,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  item['time'] as String,
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary.withAlpha(150)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

