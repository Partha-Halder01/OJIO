<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PaymentOrder;
use App\Models\PremiumPackage;
use App\Models\User;
use App\Services\PaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PremiumPackageController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(['status' => 'success', 'data' => PremiumPackage::where('is_active', true)->orderBy('price')->get()]);
    }

    public function createOrder(Request $request, PaymentService $payments): JsonResponse
    {
        $data = $request->validate(['package_id' => 'required|integer|exists:premium_packages,id', 'coupon_code' => 'nullable|string|max:100']);
        $order = $payments->packageOrder($request->user(), $data['package_id'], $data['coupon_code'] ?? null, 'razorpay');

        return response()->json(['status' => 'success', 'data' => $payments->createRazorpayOrder($order)]);
    }

    public function verifyPayment(Request $request, PaymentService $payments): JsonResponse
    {
        $data = $request->validate([
            'razorpay_payment_id' => 'required|string|max:100',
            'razorpay_order_id' => 'required|string|max:100',
            'razorpay_signature' => 'required|string|size:64',
        ]);
        $order = PaymentOrder::where('user_id', $request->user()->id)
            ->where('provider_order_id', $data['razorpay_order_id'])->firstOrFail();
        $payments->verify($order, $data['razorpay_payment_id'], $data['razorpay_signature']);
        $order->refresh();

        return response()->json(['status' => 'success', 'message' => 'Payment verified successfully.', 'data' => [
            'status' => $order->status, 'order_id' => $order->id,
            'razorpay_order_id' => $order->provider_order_id, 'payment_id' => $order->provider_payment_id,
            'purpose' => $order->purpose, 'amount_paise' => $order->amount_paise,
            'user' => $request->user()->fresh()->append('free_ads_limit'),
        ]]);
    }

    public function payWithWallet(Request $request, PaymentService $payments): JsonResponse
    {
        $data = $request->validate([
            'package_id' => 'required|integer|exists:premium_packages,id',
            'coupon_code' => 'nullable|string|max:100', 'request_id' => 'required|uuid',
        ]);
        $order = DB::transaction(function () use ($request, $data, $payments) {
            $user = User::lockForUpdate()->findOrFail($request->user()->id);
            $order = PaymentOrder::where('user_id', $user->id)->where('request_id', $data['request_id'])->first();
            if ($order) {
                abort_unless($order->package_id === (int) $data['package_id'] && $order->provider === 'wallet', 422, 'Invalid checkout request.');
            } else {
                $order = $payments->packageOrder($user, $data['package_id'], $data['coupon_code'] ?? null, 'wallet', $data['request_id']);
            }
            $payments->payWithWallet($order);

            return $order;
        });

        return response()->json(['status' => 'success', 'message' => 'Premium purchased using your wallet.', 'data' => [
            'status' => $order->fresh()->status, 'provider' => 'wallet', 'purpose' => 'premium',
            'order_id' => $order->id, 'amount_paise' => $order->amount_paise, 'user' => $request->user()->fresh()->append('free_ads_limit'),
        ]]);
    }
}
