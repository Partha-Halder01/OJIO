import '../widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final newP = _newCtrl.text.trim();
    final confirmP = _confirmCtrl.text.trim();

    if (current.isEmpty || newP.isEmpty || confirmP.isEmpty) {
      AppNotice.show(
        context,
        const SnackBar(content: Text('Please fill in all password fields.')),
      );
      return;
    }

    if (newP.length < 6) {
      AppNotice.show(
        context,
        const SnackBar(
          content: Text('New password must be at least 6 characters.'),
        ),
      );
      return;
    }

    if (newP != confirmP) {
      AppNotice.show(
        context,
        const SnackBar(content: Text('New passwords do not match.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await ApiService().changePassword(current, newP, confirmP);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res != null && res['status'] == 'success') {
      AppNotice.show(
        context,
        SnackBar(
          backgroundColor: Colors.green.shade800,
          content: Text(
            res['message'] ?? 'Password changed successfully!',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      Navigator.pop(context);
    } else {
      AppNotice.show(
        context,
        SnackBar(
          backgroundColor: Colors.red.shade800,
          content: Text(
            res?['message'] ??
                'Failed to change password. Check current password.',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Change Password',
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create New Password',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Your new password must be different from previously used passwords.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Current Password
            TextField(
              controller: _currentCtrl,
              obscureText: _hideCurrent,
              style: GoogleFonts.outfit(fontSize: 14),
              decoration: _inputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.key_outlined, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _hideCurrent ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _hideCurrent = !_hideCurrent),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // New Password
            TextField(
              controller: _newCtrl,
              obscureText: _hideNew,
              style: GoogleFonts.outfit(fontSize: 14),
              decoration: _inputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _hideNew ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _hideNew = !_hideNew),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm New Password
            TextField(
              controller: _confirmCtrl,
              obscureText: _hideConfirm,
              style: GoogleFonts.outfit(fontSize: 14),
              decoration: _inputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.check_circle_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _hideConfirm ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Update Password',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Hint card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keep your password confidential. OJIO administrators will never ask for your password.',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.outfit(
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
