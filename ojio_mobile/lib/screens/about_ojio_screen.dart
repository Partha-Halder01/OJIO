import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import 'legal_document_screen.dart';

class AboutOjioScreen extends StatelessWidget {
  const AboutOjioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          'About OJIO',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF087CF5), Color(0xFF0056B3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF087CF5).withAlpha(80),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'O',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'OJIO Marketplace',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0D1B2A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Next-Generation Classifieds Platform',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF087CF5).withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Version 1.0.0 (Production Build)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF087CF5),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(18),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our Mission',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D1B2A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'OJIO connects local buyers and sellers across Indian cities with a seamless, safe, and lightning-fast marketplace experience. Buy electronics, vehicles, property, and everyday goods with instant chat.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildLegalTile(
                    context,
                    Icons.policy_outlined,
                    LegalDocument.terms,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildLegalTile(
                    context,
                    Icons.privacy_tip_outlined,
                    LegalDocument.privacy,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Text(
              'Made with ❤️ for smart buyers & sellers',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalTile(
    BuildContext context,
    IconData icon,
    LegalDocument document,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF087CF5), size: 22),
      title: Text(
        document.title,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: AppColors.textSecondary,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LegalDocumentScreen(document: document),
        ),
      ),
    );
  }
}
