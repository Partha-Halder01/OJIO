import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.darkBrand,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/welcome_background.png',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.darkBrand),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          children: [
                            SizedBox(
                              height: (screenHeight * 0.22).clamp(24.0, 200.0),
                            ),

                            // Logo
                            SizedBox(
                              width: 180,
                              height: 80,
                              child: Image.asset(
                                'assets/images/logo_tight.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Text(
                                  'OJIO',
                                  style: GoogleFonts.outfit(
                                    fontSize: 56,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -2,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.04),

                            // Tagline
                            Text(
                              'Buy. Sell. Connect.',
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Discover local deals.\nGive your unused items a new home.',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white60,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 30),

                            // Simple marketplace features, without promotional badges.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _feature(Icons.near_me_outlined, 'Find nearby'),
                                _feature(
                                  Icons.chat_bubble_outline_rounded,
                                  'Chat directly',
                                ),
                                _feature(Icons.sell_outlined, 'Sell simply'),
                              ],
                            ),

                            SizedBox(height: screenHeight * 0.06),

                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 48),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SignUpScreen(),
                                        ),
                                      ),
                                      child: Text(
                                        'Create Account',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Log In button
                                  Expanded(
                                    flex: 1,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Colors.white30,
                                          width: 1.5,
                                        ),
                                        backgroundColor: AppColors.darkBrand
                                            .withAlpha(210),
                                        minimumSize: const Size(0, 48),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LoginScreen(),
                                        ),
                                      ),
                                      child: Text(
                                        'Log In',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            SizedBox(height: screenHeight * 0.04),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.primaryAccent),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
