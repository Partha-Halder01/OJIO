import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/services/api_service.dart';
import 'package:ojio_mobile/services/auth_service.dart';
import 'package:ojio_mobile/services/payment_checkout.dart';
import 'package:ojio_mobile/services/payment_flow.dart';
import 'package:ojio_mobile/services/payment_result.dart';

const seller = {
  'id': 1,
  'name': 'Seller',
  'city': 'Kolkata',
  'is_premium': false,
  'wallet_balance_paise': 0,
};

class PaymentApi extends ApiService {
  int verifications = 0;
  Map<String, dynamic> order = {
    'id': 20,
    'order_id': 'order_current',
    'key_id': 'rzp_live_example',
    'amount': 50000,
    'currency': 'INR',
    'status': 'pending',
    'purpose': 'wallet_topup',
  };
  Map<String, dynamic> confirmation = {
    'status': 'paid',
    'razorpay_order_id': 'order_current',
    'payment_id': 'pay_current',
    'amount_paise': 50000,
    'purpose': 'wallet_topup',
    'user': {...seller, 'wallet_balance_paise': 50000},
  };
  @override
  Future<Map<String, dynamic>> paymentOrder({
    int? packageId,
    int? amountPaise,
    String? couponCode,
  }) async => order;
  @override
  Future<Map<String, dynamic>> verifyPayment({
    required int packageId,
    required String paymentId,
    String? orderId,
    String? signature,
    String? couponCode,
    double? discountAmount,
  }) async {
    verifications++;
    return confirmation;
  }
}

class CheckoutStub implements PaymentCheckout {
  CheckoutStub({
    this.result = const PaymentResult(
      'pay_current',
      'order_current',
      'signature',
    ),
  });
  final PaymentResult result;
  int opened = 0;
  @override
  Future<PaymentResult> open(Map<String, dynamic> options) async {
    opened++;
    return result;
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('razorpay_flutter');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService().token = 'seller-token';
    AuthService().currentUser = UserModel.fromJson(seller);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
    AuthService().token = null;
    AuthService().currentUser = null;
    AuthService().location.value = null;
  });

  for (final code in [2, 0]) {
    test(
      'Android cancelled/failed checkout ($code) cannot call payment verification or show success',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (_) async => {
                'type': 1,
                'data': {'code': code, 'message': 'Payment failed'},
              },
            );
        final checkout = PaymentCheckout();
        final api = PaymentApi();
        await expectLater(
          runPayment(
            checkout,
            amountPaise: 50000,
            description: 'Wallet',
            api: api,
          ),
          throwsA(isA<Exception>()),
        );
        expect(api.verifications, 0);
        expect(AuthService().currentUser?.isPremium, false);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('auth_user'), isNull);
        checkout.dispose();
      },
    );
  }

  test(
    'checkout result for another order is rejected before verification',
    () async {
      final api = PaymentApi();
      final checkout = CheckoutStub(
        result: const PaymentResult('pay_other', 'order_other', 'signature'),
      );
      await expectLater(
        runPayment(
          checkout,
          amountPaise: 50000,
          description: 'Wallet',
          api: api,
        ),
        throwsA(isA<Exception>()),
      );
      expect(api.verifications, 0);
    },
  );

  test(
    'SDK success cannot grant benefits while server says payment is pending',
    () async {
      final api = PaymentApi();
      api.confirmation['status'] = 'pending';
      await expectLater(
        runPayment(
          CheckoutStub(),
          amountPaise: 50000,
          description: 'Wallet',
          api: api,
        ),
        throwsA(isA<Exception>()),
      );
      expect(api.verifications, 1);
      expect(AuthService().currentUser?.isPremium, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_user'), isNull);
    },
  );

  test(
    'invalid keys and positive amounts marked paid before checkout are blocked',
    () async {
      for (final change in [
        {'key_id': 'invalid_key'},
        {'status': 'paid'},
      ]) {
        final api = PaymentApi();
        api.order.addAll(change);
        final checkout = CheckoutStub();
        await expectLater(
          runPayment(
            checkout,
            amountPaise: 50000,
            description: 'Wallet',
            api: api,
          ),
          throwsA(isA<Exception>()),
        );
        expect(checkout.opened, 0);
        expect(api.verifications, 0);
      }
    },
  );

  for (final purpose in ['wallet_topup', 'premium']) {
    for (final code in [2, 0]) {
      test(
        'Android test $purpose opens checkout and reports failure ($code)',
        () async {
          var opens = 0;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                if (call.method == 'open') {
                  opens++;
                  return {
                    'type': 1,
                    'data': {'code': code, 'message': 'Payment failed'},
                  };
                }
                return null;
              });
          final api = PaymentApi();
          api.order.addAll({'key_id': 'rzp_test_example', 'purpose': purpose});
          final checkout = PaymentCheckout();
          await expectLater(
            runPayment(
              checkout,
              amountPaise: purpose == 'wallet_topup' ? 50000 : null,
              packageId: purpose == 'premium' ? 3 : null,
              description: purpose,
              api: api,
            ),
            throwsA(isA<Exception>()),
          );
          expect(opens, 1);
          expect(api.verifications, 0);
          expect(AuthService().currentUser?.isPremium, false);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('auth_user'), isNull);
          checkout.dispose();
        },
      );
    }

    test(
      'simulated successful $purpose opens checkout without granting real benefits',
      () async {
        final api = PaymentApi();
        api.order.addAll({'key_id': 'rzp_test_example', 'purpose': purpose});
        final checkout = CheckoutStub();
        await expectLater(
          runPayment(
            checkout,
            amountPaise: purpose == 'wallet_topup' ? 50000 : null,
            packageId: purpose == 'premium' ? 3 : null,
            description: purpose,
            api: api,
          ),
          throwsA(
            predicate(
              (error) => error.toString().contains('not a real payment'),
            ),
          ),
        );
        expect(checkout.opened, 1);
        expect(api.verifications, 0);
        expect(AuthService().currentUser?.isPremium, false);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('auth_user'), isNull);
      },
    );
  }

  test(
    'wallet success requires server-confirmed matching order, amount, payment and purpose',
    () async {
      for (final change in [
        {'razorpay_order_id': 'another_order'},
        {'payment_id': 'another_payment'},
        {'amount_paise': 100},
        {'purpose': 'premium'},
      ]) {
        final api = PaymentApi();
        api.confirmation.addAll(change);
        await expectLater(
          runPayment(
            CheckoutStub(),
            amountPaise: 50000,
            description: 'Wallet',
            api: api,
          ),
          throwsA(isA<Exception>()),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_user'), isNull);
    },
  );

  test(
    'only confirmed top-up applies the balance returned by the server',
    () async {
      final api = PaymentApi();
      await runPayment(
        CheckoutStub(),
        amountPaise: 50000,
        description: 'Wallet',
        api: api,
      );
      expect(api.verifications, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('auth_user')!)['wallet_balance_paise'],
        50000,
      );
    },
  );

  test(
    'premium badge is applied only after confirmed premium payment',
    () async {
      final api = PaymentApi();
      api.order.addAll({'purpose': 'premium', 'amount': 4900});
      api.confirmation.addAll({
        'purpose': 'premium',
        'amount_paise': 4900,
        'user': {
          ...seller,
          'is_premium': true,
          'has_diamond_badge': true,
          'paid_ads_quota': 5,
        },
      });
      await runPayment(
        CheckoutStub(),
        packageId: 3,
        description: 'Premium',
        api: api,
      );
      expect(AuthService().currentUser?.hasDiamondBadge, true);
      expect(AuthService().currentUser?.paidAdsQuota, 5);
    },
  );

  test(
    'complimentary server-approved premium does not open checkout',
    () async {
      final api = PaymentApi();
      api.order.addAll({
        'purpose': 'premium',
        'amount': 0,
        'status': 'paid',
        'user': {...seller, 'is_premium': true, 'paid_ads_quota': 1},
      });
      final checkout = CheckoutStub();
      await runPayment(
        checkout,
        packageId: 3,
        description: 'Premium',
        api: api,
      );
      expect(checkout.opened, 0);
      expect(api.verifications, 0);
      expect(AuthService().currentUser?.paidAdsQuota, 1);
    },
  );

  test(
    'insufficient wallet balance throws and does not grant a premium badge',
    () async {
      final api = ApiService(
        client: MockClient(
          (_) async =>
              http.Response('{"message":"Insufficient wallet balance."}', 422),
        ),
      );
      await expectLater(
        api.payWithWallet(3, checkoutRequestId()),
        throwsA(isA<ApiException>()),
      );
      expect(AuthService().currentUser?.hasDiamondBadge, false);
    },
  );

  test(
    'wallet purchase only applies authoritative user state for a paid wallet order',
    () async {
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'status': 'paid',
                'provider': 'wallet',
                'purpose': 'premium',
                'user': {
                  ...seller,
                  'has_diamond_badge': true,
                  'paid_ads_quota': 5,
                  'wallet_balance_paise': 0,
                },
              },
            }),
            200,
          ),
        ),
      );
      await api.payWithWallet(3, checkoutRequestId());
      expect(AuthService().currentUser?.hasDiamondBadge, true);
      expect(AuthService().currentUser?.paidAdsQuota, 5);
    },
  );
}
