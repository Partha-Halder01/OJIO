import '../widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/payment_checkout.dart';
import '../services/payment_flow.dart';
import 'login_screen.dart';

class WalletScreen extends StatefulWidget {
  final ApiService? api;
  const WalletScreen({super.key, this.api});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final ApiService _api;
  final _checkout = PaymentCheckout();
  final _amount = TextEditingController(text: '500');
  Map<String, dynamic>? _wallet;
  String? _error;
  bool _loading = false;
  bool _paying = false;
  String _money(num paise) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(paise / 100);

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _load();
  }

  @override
  void dispose() {
    _checkout.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!AuthService().isAuthenticated) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallet = await _api.wallet();
      if (mounted) setState(() => _wallet = wallet);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMoney() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || !amount.isFinite || amount < 100 || amount > 10000) {
      AppNotice.show(
        context,
        const SnackBar(
          content: Text('Enter an amount between ₹100 and ₹10,000.'),
        ),
      );
      return;
    }
    setState(() => _paying = true);
    try {
      await runPayment(
        _checkout,
        amountPaise: (amount * 100).round(),
        description: 'OJIO Wallet top-up',
      );
      if (mounted) {
        AppNotice.show(
          context,
          const SnackBar(content: Text('Money added to your wallet.')),
        );
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
      if (mounted) {
        setState(() => _paying = false);
        await _load();
      }
    }
  }

  Future<void> _checkPayment(int id) async {
    setState(() => _paying = true);
    try {
      final result = await _api.reconcilePayment(id);
      await _api.fetchUserProfile();
      if (mounted) {
        AppNotice.show(
          context,
          SnackBar(
            content: Text(
              result['status'] == 'paid'
                  ? 'Payment confirmed.'
                  : 'No captured payment yet. You can check again later.',
            ),
          ),
        );
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
      if (mounted) {
        setState(() => _paying = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = (_wallet?['transactions'] as List?) ?? [];
    final pending = (_wallet?['pending_orders'] as List?) ?? [];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('OJIO Wallet'),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.darkBrand,
      ),
      body: !AuthService().isAuthenticated
          ? Center(
              child: FilledButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Log in to use your wallet'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(returnToPrevious: true),
                    ),
                  );
                  if (mounted) {
                    setState(() {});
                    await _load();
                  }
                },
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.darkBrand,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available balance',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _wallet == null
                              ? '—'
                              : _money(_wallet!['balance_paise'] as num),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Use your balance for OJIO premium ad packages.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                  Text(
                    'Add money',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amount,
                    enabled: !_paying,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [100, 500, 1000]
                        .map(
                          (amount) => ActionChip(
                            label: Text('₹$amount'),
                            onPressed: _paying
                                ? null
                                : () => _amount.text = '$amount',
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _paying ? null : _addMoney,
                    icon: const Icon(Icons.add),
                    label: Text(_paying ? 'Processing…' : 'Add money securely'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Payments are processed by Razorpay. Wallet balance can be used only for OJIO services.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (pending.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Check recent payments',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    ...pending.map(
                      (order) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          order['purpose'] == 'wallet_topup'
                              ? 'Wallet top-up'
                              : 'Premium package',
                        ),
                        subtitle: Text(_money(order['amount_paise'] as num)),
                        trailing: TextButton(
                          onPressed: _paying
                              ? null
                              : () => _checkPayment(order['id'] as int),
                          child: const Text('Check status'),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Transaction history',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  if (transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Your wallet transactions will appear here.'),
                    ),
                  ...transactions.map((transaction) {
                    final amount = transaction['amount_paise'] as num;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        amount > 0 ? Icons.south_west : Icons.north_east,
                        color: amount > 0 ? Colors.green : AppColors.primary,
                      ),
                      title: Text(transaction['description'].toString()),
                      subtitle: Text(
                        DateFormat.yMMMd().add_jm().format(
                          DateTime.parse(transaction['created_at']).toLocal(),
                        ),
                      ),
                      trailing: Text(
                        '${amount > 0 ? '+' : '-'}${_money(amount.abs())}',
                        style: TextStyle(
                          color: amount > 0 ? Colors.green : AppColors.textMain,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
