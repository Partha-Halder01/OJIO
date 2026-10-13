class PaymentResult {
  final String paymentId;
  final String orderId;
  final String signature;
  const PaymentResult(this.paymentId, this.orderId, this.signature);
}
