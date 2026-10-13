import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class PrivacySafetyScreen extends StatelessWidget {
  const PrivacySafetyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          'Privacy & Safety',
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D1B2A), Color(0xFF1E3A5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF087CF5).withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF087CF5), size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Security Status',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your account is secured with email and encrypted credentials.',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'SAFETY TIPS FOR BUYING & SELLING',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          _buildTipCard(
            Icons.handshake_outlined,
            'Meet in Safe Public Places',
            'Always choose well-lit, public locations like metro stations or cafes when meeting in person.',
          ),
          _buildTipCard(
            Icons.credit_card_off_outlined,
            'Inspect Item Before Payment',
            'Never send full advance payments or scan unknown QR codes before thoroughly inspecting the product.',
          ),
          _buildTipCard(
            Icons.lock_outline_rounded,
            'Protect Personal Information',
            'Never share sensitive details like OTPs, banking PINs, or ID card numbers with strangers.',
          ),
          _buildTipCard(
            Icons.report_problem_outlined,
            'Report Suspicious Activity',
            'If you notice suspicious listings or abusive behavior, report them immediately to our moderation team.',
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF087CF5).withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF087CF5), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

