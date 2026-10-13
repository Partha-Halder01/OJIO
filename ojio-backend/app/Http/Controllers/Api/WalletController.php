<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PaymentOrder;
use App\Services\PaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WalletController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        return response()->json(['status' => 'success', 'data' => [
            'balance_paise' => (int) $request->user()->wallet_balance_paise,
            'transactions' => DB::table('wallet_transactions')->where('user_id', $request->user()->id)->latest('id')->limit(50)->get(),
            'pending_orders' => PaymentOrder::where('user_id', $request->user()->id)->where('status', 'pending')
                ->whereNotNull('provider_order_id')->latest()->limit(10)->get(['id', 'purpose', 'amount_paise', 'created_at']),
        ]]);
    }

    public function topup(Request $request, PaymentService $payments): JsonResponse
    {
        $data = $request->validate(['amount_paise' => 'required|integer|min:10000|max:1000000']);
        $order = PaymentOrder::create(['user_id' => $request->user()->id, 'purpose' => 'wallet_topup', 'amount_paise' => $data['amount_paise']]);

        return response()->json(['status' => 'success', 'data' => $payments->createRazorpayOrder($order)]);
    }

    public function reconcile(Request $request, int $id, PaymentService $payments): JsonResponse
    {
        $order = PaymentOrder::where('user_id', $request->user()->id)->findOrFail($id);
        $payments->reconcile($order);

        return response()->json(['status' => 'success', 'data' => ['status' => $order->fresh()->status]]);
    }
}
