import '../widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/google_auth_button.dart';
import '../widgets/auth_page_layout.dart';
import 'login_screen.dart';
import 'legal_document_screen.dart';
import 'main_screen.dart';

class SignUpScreen extends StatefulWidget {
  final bool returnToPrevious;
  final ApiService? api;
  final bool completeContact;
  const SignUpScreen({
    super.key,
    this.returnToPrevious = false,
    this.api,
    this.completeContact = false,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _needsGoogleContact = false;
  bool _isLoading = false;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _needsGoogleContact = widget.completeContact;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _finishSignUp() async {
    if (!mounted) return;
    if ((AuthService().currentUser?.phone ?? '').isEmpty) {
      setState(() => _needsGoogleContact = true);
      AppNotice.show(
        context,
        const SnackBar(
          content: Text(
            'Enter your mobile number below to finish creating your account.',
          ),
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

  Future<void> _signUp() async {
    if (_isLoading) return;
    if (_needsGoogleContact) {
      await _saveGoogleContact();
      return;
    }
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty) {
      AppNotice.show(
        context,
        const SnackBar(content: Text('Please fill out all fields.')),
      );
      return;
    }
    if (!RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(_emailCtrl.text.trim())) {
      AppNotice.show(
        context,
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }
    if (_passCtrl.text.length < 6) {
      AppNotice.show(
        context,
        const SnackBar(
          content: Text('Use a password with at least 6 characters.'),
        ),
      );
      return;
    }
    if (!_validPhone()) return;
    setState(() => _isLoading = true);

    try {
      final res = await (widget.api ?? ApiService()).register(
        _nameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passCtrl.text,
        phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;

      if (res != null && res['status'] == 'success') {
        await AuthService().setAuth(res['token'], res['user']);
        if (!mounted) return;
        await _finishSignUp();
      } else {
        if (!mounted) return;
        AppNotice.show(
          context,
          SnackBar(
            content: Text(
              res?['message'] ??
                  'Registration failed. Check if email is already in use.',
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
                : 'Unable to create your account. Check your connection and retry.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validPhone() {
    if (RegExp(r'^(?:\+91)?[6-9][0-9]{9}$').hasMatch(_phoneCtrl.text.trim())) {
      return true;
    }
    AppNotice.show(
      context,
      const SnackBar(content: Text('Enter a valid 10-digit mobile number.')),
    );
    return false;
  }

  Future<void> _saveGoogleContact() async {
    if (!_validPhone()) return;
    final session = AuthService().token;
    setState(() => _isLoading = true);
    try {
      final result = await (widget.api ?? ApiService()).updateProfileDetails(
        AuthService().currentUser!.name,
        _phoneCtrl.text.trim(),
      );
      if (!mounted || session != AuthService().token) return;
      await AuthService().updateUser(Map<String, dynamic>.from(result['user']));
      await _finishSignUp();
    } catch (error) {
      if (mounted) {
        AppNotice.show(
          context,
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Unable to save your mobile number. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp(
    GoogleSignInAccount account,
    String token,
  ) async {
    await _executeFirebaseSignUp(
      account.email,
      account.displayName ?? account.email.split('@').first,
      avatar: account.photoUrl,
      uid: account.id,
      idToken: token,
    );
  }

  Future<void> _executeFirebaseSignUp(
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

        await _finishSignUp();
      } else {
        if (!mounted) return;
        AppNotice.show(
          context,
          SnackBar(
            content: Text(res?['message'] ?? 'Google sign up failed.'),
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
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop &&
            _needsGoogleContact &&
            (AuthService().currentUser?.phone ?? '').isEmpty) {
          AuthService().logout();
        }
      },
      child: AuthPageLayout(
        busy: _isLoading,
        dark: false,
        children: [
          Text(
            'Create Account',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.darkBrand,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join OJIO and start exploring deals near you.',
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          if (!_needsGoogleContact) ...[
            TextField(
              enabled: !_isLoading,
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              enabled: !_isLoading,
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
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
          ],
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('signup-phone'),
            enabled: !_isLoading,
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              prefixIcon: Icon(Icons.phone_outlined),
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
            onPressed: _isLoading ? null : _signUp,
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
                    _needsGoogleContact ? 'Complete Account' : 'Sign Up',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          if (!_needsGoogleContact) ...[
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
              onAuthenticated: _handleGoogleSignUp,
            ),
          ],
          const SizedBox(height: 24),
          Row(
            key: const ValueKey('signup-footer'),
            children: [
              Expanded(
                flex: 6,
                child: Text(
                  "Already have an account?",
                  style: GoogleFonts.outfit(fontSize: 13),
                ),
              ),
              Flexible(
                flex: 2,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_needsGoogleContact) await AuthService().logout();
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoginScreen(
                                returnToPrevious: widget.returnToPrevious,
                                api: widget.api,
                              ),
                            ),
                          );
                        },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Login',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                flex: 2,
                child: Tooltip(
                  message: 'Terms & Conditions',
                  child: TextButton(
                    key: const ValueKey('signup-terms-link'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LegalDocumentScreen(
                                document: LegalDocument.terms,
                                api: widget.api,
                              ),
                            ),
                          ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('T&C'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
