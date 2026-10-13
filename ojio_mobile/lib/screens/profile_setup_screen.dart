import '../widgets/app_notice.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'main_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool returnToPrevious;
  const ProfileSetupScreen({super.key, this.returnToPrevious = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _phoneCtrl.text = user?.phone ?? '';
    _cityCtrl.text = user?.city ?? '';
    _stateCtrl.text = user?.state ?? '';
    _countryCtrl.text = user?.country ?? 'India';
  }

  @override
  void dispose() {
    for (final controller in [
      _phoneCtrl,
      _cityCtrl,
      _stateCtrl,
      _countryCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!RegExp(r'^(?:\+91)?[6-9][0-9]{9}$').hasMatch(_phoneCtrl.text.trim())) {
      AppNotice.show(
        context,
        const SnackBar(content: Text('Enter a valid 10-digit mobile number')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final res = await ApiService().updateProfile(
        AuthService().currentUser?.name ?? '',
        _phoneCtrl.text.trim(),
        _cityCtrl.text,
        _stateCtrl.text,
        _countryCtrl.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res != null && res['status'] == 'success') {
        await AuthService().updateUser(res['user']);
        if (mounted) {
          if (widget.returnToPrevious) {
            Navigator.pop(context, true);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainScreen()),
            );
          }
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (error) {
      if (mounted) {
        AppNotice.show(
          context,
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: const Text(
              'Save contact',
              style: TextStyle(
                color: AppConstants.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Almost there!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your mobile number is required so buyers can reach you. Other profile details are optional and can be added later.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Number *',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityCtrl,
              decoration: InputDecoration(
                labelText: 'City',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _stateCtrl,
              decoration: InputDecoration(
                labelText: 'State',
                prefixIcon: const Icon(Icons.map),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countryCtrl,
              decoration: InputDecoration(
                labelText: 'Country',
                prefixIcon: const Icon(Icons.public),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Complete Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading ? null : _submit,
              child: const Text(
                'Save contact & finish other details later',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
