import '../widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/payment_checkout.dart';
import '../services/payment_flow.dart';
import '../screens/login_screen.dart';
import '../screens/wallet_screen.dart';

class PaywallModal extends StatefulWidget {
  final ApiService? api;
  final VoidCallback onPaymentSuccess;
  const PaywallModal({super.key, required this.onPaymentSuccess, this.api});
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onPaymentSuccess,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PaywallModal(onPaymentSuccess: onPaymentSuccess),
  );
  @override
  State<PaywallModal> createState() => _PaywallModalState();
}

class _PaywallModalState extends State<PaywallModal> {
  late final ApiService _api;
  final _checkout = PaymentCheckout();
  final _coupon = TextEditingController();
  List<PremiumPackageModel> _packages = [];
  int _selected = 0;
  int _balance = 0;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _appliedCoupon;
  double _discount = 0;
  String? _walletRequest;
  int? _walletRequestPackage;
  String? _walletRequestCoupon;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _load();
  }

  @override
  void dispose() {
    _checkout.dispose();
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final packages = await _api.fetchPackages();
      if (AuthService().isAuthenticated) {
        final wallet = await _api.wallet();
        _balance = wallet['balance_paise'] as int;
      }
      if (mounted) {
        setState(() {
          _packages = packages;
          _loading = false;
          _error = packages.isEmpty
              ? 'Packages are unavailable. Please retry.'
              : null;
        });
        if (_error != null) _message(_error!);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
        _message(_error!);
      }
    }
  }

  void _message(String text) {
    if (mounted) {
      AppNotice.show(context, SnackBar(content: Text(text)));
    }
  }

  Future<void> _applyCoupon() async {
    if (_packages.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final code = _coupon.text.trim().toUpperCase();
      final result = await _api.validateCoupon(
        code,
        _packages[_selected].price,
      );
      if (!mounted) return;
      setState(() {
        _appliedCoupon = result == null ? null : code;
        _discount =
            double.tryParse(result?['discount']?.toString() ?? '0') ?? 0;
      });
      _message(
        result == null ? 'Invalid or expired coupon.' : 'Coupon applied.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay({required bool wallet}) async {
    if (_busy || _packages.isEmpty) return;
    if (!AuthService().isAuthenticated) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(returnToPrevious: true),
        ),
      );
      if (!mounted || !AuthService().isAuthenticated) return;
    }
    final package = _packages[_selected];
    final coupon = _appliedCoupon;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (wallet) {
        if (_walletRequest == null ||
            _walletRequestPackage != package.id ||
            _walletRequestCoupon != coupon) {
          _walletRequest = checkoutRequestId();
          _walletRequestPackage = package.id;
          _walletRequestCoupon = coupon;
        }
        await _api.payWithWallet(
          package.id,
          _walletRequest!,
          couponCode: coupon,
        );
      } else {
        await runPayment(
          _checkout,
          packageId: package.id,
          couponCode: coupon,
          description: package.name,
        );
      }
      if (!mounted) return;
      final callback = widget.onPaymentSuccess;
      Navigator.pop(context);
      callback();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
        _message(_error!);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMoney() async {
    if (_busy) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WalletScreen(api: _api)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final price = _packages.isEmpty
        ? 0.0
        : (_packages[_selected].price - _discount).clamp(
            0.0,
            _packages[_selected].price,
          );
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .9,
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Post more with OJIO Premium',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a package to publish your ad. Your filled details stay saved while you complete payment.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                if (_loading) const Center(child: CircularProgressIndicator()),
                ..._packages.asMap().entries.map((entry) {
                  final package = entry.value;
                  final selected = _selected == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: _busy
                          ? null
                          : () => setState(() {
                              _selected = entry.key;
                              _discount = 0;
                              _appliedCoupon = null;
                              _coupon.clear();
                            }),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFEFF6FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    package.name,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (package.description != null)
                                    Text(
                                      package.description!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${package.price.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (_packages.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _coupon,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Coupon code',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _applyCoupon,
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Wallet balance: ₹${(_balance / 100).toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _addMoney,
                    child: const Text('Wallet / check payment status'),
                  ),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : _balance < (price * 100).round()
                        ? _addMoney
                        : () => _pay(wallet: true),
                    child: Text(
                      _busy
                          ? 'Processing…'
                          : _balance < (price * 100).round()
                          ? 'Add money to wallet'
                          : 'Pay ₹${price.toStringAsFixed(2)} from wallet',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _pay(wallet: false),
                    child: Text(
                      'Pay ₹${price.toStringAsFixed(2)} by UPI or cards',
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  if (_packages.isEmpty)
                    TextButton(onPressed: _load, child: const Text('Retry')),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Payments are confirmed securely before your quota is updated.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
