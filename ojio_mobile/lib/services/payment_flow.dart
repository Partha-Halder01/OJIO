import 'dart:math';
import 'api_service.dart';
import 'auth_service.dart';
import 'payment_checkout.dart';

String checkoutRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final value = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}

Future<void> runPayment(
  PaymentCheckout checkout, {
  int? packageId,
  int? amountPaise,
  String? couponCode,
  required String description,
  ApiService? api,
}) async {
  api ??= ApiService();
  final session = AuthService().token;
  if ((packageId == null) == (amountPaise == null)) {
    throw ArgumentError('Choose either a wallet top-up or a premium package.');
  }
  final purpose = amountPaise != null ? 'wallet_topup' : 'premium';
  final order = await api.paymentOrder(
    packageId: packageId,
    amountPaise: amountPaise,
    couponCode: couponCode,
  );
  final amount = int.tryParse('${order['amount']}');
  if (session != AuthService().token ||
      order['purpose'] != purpose ||
      order['currency'] != 'INR' ||
      amount == null ||
      amount < 0 ||
      (amountPaise != null && amount != amountPaise)) {
    throw Exception(
      'Payment order could not be confirmed. No payment was completed.',
    );
  }
  Map<String, dynamic> confirmed = order;
  if (amount > 0) {
    final key = order['key_id']?.toString() ?? '';
    final isTestCheckout = key.startsWith('rzp_test_');
    if (order['status'] != 'pending' ||
        order['order_id'] is! String ||
        order['order_id'].isEmpty ||
        !(key.startsWith('rzp_live_') || isTestCheckout)) {
      throw Exception(
        'Payment checkout could not be opened. No wallet money or premium benefits were added.',
      );
    }
    final user = AuthService().currentUser;
    final result = await checkout.open({
      'key': order['key_id'],
      'order_id': order['order_id'],
      'amount': order['amount'],
      'currency': 'INR',
      'name': 'OJIO',
      'description': description,
      'prefill': {'contact': user?.phone ?? '', 'email': user?.email ?? ''},
      'theme': {'color': '#087CF5'},
    });
    if (result.orderId != order['order_id'] ||
        result.paymentId.isEmpty ||
        result.signature.isEmpty ||
        session != AuthService().token) {
      throw Exception(
        'Payment response did not match this checkout. Check payment status before paying again.',
      );
    }
    if (isTestCheckout) {
      throw Exception(
        'This was a test checkout, not a real payment. No wallet money or premium benefits were added.',
      );
    }
    confirmed = await api.verifyPayment(
      packageId: packageId ?? 0,
      paymentId: result.paymentId,
      orderId: result.orderId,
      signature: result.signature,
    );
    if (confirmed['status'] != 'paid' ||
        confirmed['razorpay_order_id'] != order['order_id'] ||
        confirmed['payment_id'] != result.paymentId ||
        confirmed['purpose'] != purpose ||
        int.tryParse('${confirmed['amount_paise']}') != amount) {
      throw Exception(
        'Payment confirmation is pending. Open Wallet and check payment status before paying again.',
      );
    }
  } else if (purpose != 'premium' || order['status'] != 'paid') {
    throw Exception('Payment has not been confirmed.');
  }
  if (session != AuthService().token ||
      confirmed['user'] is! Map ||
      confirmed['user']['id'] != AuthService().currentUserId) {
    throw Exception('Payment status must be checked after logging in again.');
  }
  await AuthService().updateUser(Map<String, dynamic>.from(confirmed['user']));
}
