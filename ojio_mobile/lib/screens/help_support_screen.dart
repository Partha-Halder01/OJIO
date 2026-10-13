import '../widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          'Help & Support',
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
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.support_agent_rounded,
                  size: 48,
                  color: Color(0xFF087CF5),
                ),
                const SizedBox(height: 12),
                Text(
                  'How can we help you?',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Our customer support team is available 24/7 to resolve your inquiries.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          AppNotice.show(
                            context,
                            const SnackBar(
                              content: Text('Support email: support@ojio.in'),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.email_outlined,
                          size: 18,
                          color: Color(0xFF087CF5),
                        ),
                        label: Text(
                          'Email Us',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF087CF5),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF087CF5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          AppNotice.show(
                            context,
                            const SnackBar(
                              content: Text('Support helpline: 1800-OJIO-CARE'),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.call_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Call Desk',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF087CF5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'FREQUENTLY ASKED QUESTIONS',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          _buildFaqTile(
            'How do I post a free ad on OJIO?',
            'Tap the blue "+" (Sell) button at the bottom center of the navigation bar, fill in your item title, category, price, and photos, then tap "Post Ad Now".',
          ),
          _buildFaqTile(
            'How does buyer-seller chat work?',
            'When browsing any listing, tap the "Chat" button at the bottom of the item detail page to send a direct message in real time to the seller.',
          ),
          _buildFaqTile(
            'How do I mark my item as sold?',
            'Go to Profile -> My Ads, find your active listing, tap the three dots menu or actions, and choose "Mark as Sold".',
          ),
          _buildFaqTile(
            'Are my transactions protected?',
            'We encourage meeting sellers locally in public places and inspecting items thoroughly before making any payments.',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: const Color(0xFF0D1B2A),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              answer,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
