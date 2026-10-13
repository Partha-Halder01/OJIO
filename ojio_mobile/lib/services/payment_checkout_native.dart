import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'payment_result.dart';

class PaymentCheckout {
  bool _disposed = false;
  Razorpay? _razorpay;
  Completer<PaymentResult>? _pending;

  Future<PaymentResult> open(Map<String, dynamic> options) {
    if (_disposed) return Future.error(Exception('Checkout closed.'));
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return Future.error(
        Exception('Use Android, iOS, or Chrome to make a payment.'),
      );
    }
    if (_pending != null && !_pending!.isCompleted) {
      return Future.error(Exception('A payment is already in progress.'));
    }
    final pending = Completer<PaymentResult>();
    _pending = pending;
    final expectedOrder = options['order_id'];
    _razorpay?.clear();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
        if (!pending.isCompleted) {
          if (response.orderId != null && response.orderId != expectedOrder) {
            pending.completeError(
              Exception(
                'Payment response did not match this checkout. Please check payment status.',
              ),
            );
            return;
          }
          if (response.paymentId == null ||
              response.orderId == null ||
              response.signature == null) {
            pending.completeError(
              Exception(
                'Payment response incomplete. Check payment status in your wallet.',
              ),
            );
          } else {
            pending.complete(
              PaymentResult(
                response.paymentId!,
                response.orderId!,
                response.signature!,
              ),
            );
          }
        }
      })
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
        if (!pending.isCompleted) {
          pending.completeError(
            Exception(
              response.code == Razorpay.PAYMENT_CANCELLED
                  ? 'Payment cancelled. No payment was confirmed.'
                  : response.message ??
                        'Payment failed. No payment was confirmed.',
            ),
          );
        }
      });
    try {
      _razorpay!.open(options);
    } catch (error) {
      if (!pending.isCompleted) pending.completeError(error);
    }
    return pending.future;
  }

  void dispose() {
    _disposed = true;
    _razorpay?.clear();
    if (_pending?.isCompleted == false) {
      _pending!.completeError(Exception('Checkout closed.'));
    }
  }
}
