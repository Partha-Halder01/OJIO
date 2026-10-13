import 'dart:async';
import 'dart:js_interop';
import 'payment_result.dart';

@JS('Razorpay')
extension type RazorpayJS._(JSObject _) implements JSObject {
  external factory RazorpayJS(JSObject options);
  external void open();
  external void close();
  external void on(JSString event, JSFunction callback);
}

class PaymentCheckout {
  bool _disposed = false;
  RazorpayJS? _checkout;
  Completer<PaymentResult>? _pending;

  Future<PaymentResult> open(Map<String, dynamic> options) {
    if (_disposed) return Future.error(Exception('Checkout closed.'));
    if (_pending?.isCompleted == false) {
      return Future.error(Exception('A payment is already in progress.'));
    }
    final pending = Completer<PaymentResult>();
    final expectedOrder = options['order_id'];
    _pending = pending;
    options = {
      ...options,
      'handler': ((JSObject response) {
        final data = (response.dartify() as Map).cast<String, dynamic>();
        if (pending.isCompleted) return;
        if (data['razorpay_order_id'] != null &&
            data['razorpay_order_id'] != expectedOrder) {
          pending.completeError(
            Exception(
              'Payment response did not match this checkout. Please check payment status.',
            ),
          );
          return;
        }
        if (data['razorpay_payment_id'] == null ||
            data['razorpay_order_id'] == null ||
            data['razorpay_signature'] == null) {
          pending.completeError(
            Exception(
              'Incomplete payment response. Check status in your wallet.',
            ),
          );
        } else {
          pending.complete(
            PaymentResult(
              data['razorpay_payment_id'],
              data['razorpay_order_id'],
              data['razorpay_signature'],
            ),
          );
        }
      }).toJS,
      'modal': {
        'ondismiss': (() {
          if (!pending.isCompleted) {
            pending.completeError(Exception('Payment cancelled.'));
          }
        }).toJS,
      },
    };
    try {
      _checkout = RazorpayJS(options.jsify() as JSObject);
      _checkout!.on(
        'payment.failed'.toJS,
        ((JSObject response) {
          if (!pending.isCompleted) {
            pending.completeError(Exception('Payment failed. Please retry.'));
          }
        }).toJS,
      );
      _checkout!.open();
    } catch (error) {
      pending.completeError(
        Exception('Unable to open secure checkout. Please reload and retry.'),
      );
    }
    return pending.future;
  }

  void dispose() {
    _disposed = true;
    _checkout?.close();
    if (_pending?.isCompleted == false) {
      _pending!.completeError(Exception('Checkout closed.'));
    }
  }
}
