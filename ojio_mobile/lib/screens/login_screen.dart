import '../widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/google_auth_button.dart';
import '../widgets/auth_page_layout.dart';
import 'signup_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool returnToPrevious;
  final ApiService? api;
  const LoginScreen({super.key, this.returnToPrevious = false, this.api});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _finishLogin() async {
    if (!mounted) return;
    if ((AuthService().currentUser?.phone ?? '').isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignUpScreen(
            returnToPrevious: true,
            completeContact: true,
            api: widget.api,
          ),
        ),
      );
    }
    if (!mounted) return;
    if ((AuthService().currentUser?.phone ?? '').isEmpty) {
      await AuthService().logout();
      if (!mounted) return;
      AppNotice.show(
        context,
        const SnackBar(
          content: Text('Add your contact number to finish signing in.'),
        ),
      );
      return;
    }
    if (widget.returnToPrevious) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _login() async {
    if (_isLoading) return;
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      AppNotice.show(
        context,
        const SnackBar(
          content: Text(
            'Please enter your email or mobile number and password.',
          ),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final res = await (widget.api ?? ApiService()).login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
      if (!mounted) return;

      if (res != null && res['status'] == 'success') {
        await AuthService().setAuth(res['token'], res['user']);
        if (!mounted) return;

        await _finishLogin();
      } else {
        if (!mounted) return;
        AppNotice.show(
          context,
          SnackBar(
            content: Text(
              res?['message'] ?? 'Login failed. Please verify credentials.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppNotice.show(
        context,
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'Unable to sign in. Check your connection and retry.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn(
    GoogleSignInAccount account,
    String token,
  ) async {
    await _executeFirebaseLogin(
      account.email,
      account.displayName ?? account.email.split('@').first,
      avatar: account.photoUrl,
      uid: account.id,
      idToken: token,
    );
  }

  Future<void> _executeFirebaseLogin(
    String email,
    String name, {
    String? avatar,
    String? uid,
    String? idToken,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await (widget.api ?? ApiService()).firebaseLogin(
        email: email,
        name: name,
        avatar: avatar,
        firebaseUid:
            uid ?? 'google_oauth_${DateTime.now().millisecondsSinceEpoch}',
        idToken: idToken,
      );
      if (!mounted) return;

      if (res != null && res['status'] == 'success') {
        await AuthService().setAuth(res['token'], res['user']);
        if (!mounted) return;

        await _finishLogin();
      } else {
        if (!mounted) return;
        AppNotice.show(
          context,
          SnackBar(
            content: Text(res?['message'] ?? 'Google authentication failed.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppNotice.show(
        context,
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'Google sign-in failed. Please retry.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageLayout(
      busy: _isLoading,
      dark: true,
      children: [
        Text(
          'Welcome Back',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: AppColors.darkBrand,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to your OJIO account to continue.',
          style: GoogleFonts.outfit(
            color: AppColors.textSecondary,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          enabled: !_isLoading,
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email or mobile number',
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          enabled: !_isLoading,
          controller: _passCtrl,
          obscureText: _obscurePass,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _isLoading ? null : _login,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Sign In',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 24),
        Row(
          children: const [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 24),
        GoogleAuthButton(
          onBusyChanged: (busy) {
            if (mounted) setState(() => _isLoading = busy);
          },
          enabled: !_isLoading,
          onAuthenticated: _handleGoogleSignIn,
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text("Don't have an account?", style: GoogleFonts.outfit()),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SignUpScreen(
                          returnToPrevious: widget.returnToPrevious,
                          api: widget.api,
                        ),
                      ),
                    ),
              child: Text(
                'Sign Up',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
