import '../widgets/app_notice.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/google_sign_in_errors.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'google_auth_button_platform.dart';

const googleClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue:
      '893178945153-tvaejgs71t83so9pj747kq03smp2q888.apps.googleusercontent.com',
);

final _googleSignIn = GoogleSignIn(
  clientId: kIsWeb ? googleClientId : null,
  // Android reads the matching Web OAuth client from google-services.json.
  serverClientId: kIsWeb || defaultTargetPlatform == TargetPlatform.android
      ? null
      : googleClientId,
  scopes: ['email', 'profile'],
);

class GoogleAuthButton extends StatefulWidget {
  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;
  final Future<void> Function(GoogleSignInAccount account, String idToken)
  onAuthenticated;
  const GoogleAuthButton({
    super.key,
    required this.onAuthenticated,
    this.enabled = true,
    this.onBusyChanged,
  });
  @override
  State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends State<GoogleAuthButton> {
  StreamSubscription<GoogleSignInAccount?>? _subscription;
  bool _ready = !kIsWeb;
  bool _busy = false;
  bool _launching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _subscription = _googleSignIn.onCurrentUserChanged.listen((account) {
        if (account != null && mounted && widget.enabled && !_busy) {
          unawaited(_authenticate(account));
        }
      });
      unawaited(_initializeWeb());
    }
  }

  Future<void> _initializeWeb() async {
    try {
      await _googleSignIn.signOut().timeout(const Duration(seconds: 20));
      if (mounted) {
        setState(() {
          _ready = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Google sign-in could not load. Check your connection and retry.',
        );
      }
    }
  }

  Future<void> _authenticate(GoogleSignInAccount account) async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    widget.onBusyChanged?.call(true);
    try {
      final authentication = await account.authentication;
      final token = authentication.idToken;
      if (token == null || token.isEmpty) {
        throw Exception(
          'Google did not return a sign-in credential. Please retry.',
        );
      }
      if (mounted) await widget.onAuthenticated(account, token);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(_launching);
      }
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = googleSignInErrorMessage(error);
    if (message == null) return;
    AppNotice.show(context, SnackBar(content: Text(message)));
  }

  Future<void> _signInNative() async {
    if (_launching || _busy || !widget.enabled) return;
    setState(() => _launching = true);
    widget.onBusyChanged?.call(true);
    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account != null) await _authenticate(account);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _launching = false);
        widget.onBusyChanged?.call(_busy);
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (_error != null) {
        return TextButton(onPressed: _initializeWeb, child: Text(_error!));
      }
      if (!_ready) return const Center(child: CircularProgressIndicator());
      return IgnorePointer(
        ignoring: !widget.enabled || _busy,
        child: Center(child: googleWebButton()),
      );
    }
    return OutlinedButton.icon(
      onPressed: widget.enabled && !_busy && !_launching ? _signInNative : null,
      icon: Image.asset(
        'assets/images/google_g.png',
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
      label: const Text('Continue with Google'),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
