<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Coupon;
use Illuminate\Http\Request;

class CouponController extends Controller
{
    /**
     * Get active promotional offers for app showcase.
     */
    public function index()
    {
        $coupons = Coupon::valid()
            ->forApp()
            ->latest()
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $coupons
        ]);
    }

    /**
     * Validate and apply a coupon code for ad promotion/posting.
     */
    public function validateCoupon(Request $request)
    {
        $request->validate([
            'code' => 'required|string',
            'amount' => 'required|numeric|min:0'
        ]);

        $code = strtoupper(trim($request->code));
        $coupon = Coupon::where('code', $code)->first();

        if (!$coupon) {
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid coupon code.'
            ], 404);
        }

        if (!$coupon->isValid()) {
            return response()->json([
                'status' => 'error',
                'message' => 'This coupon has expired or reached maximum usage limit.'
            ], 400);
        }

        $baseAmount = (float)$request->amount;
        $discount = 0;

        if ($coupon->type === 'percentage') {
            $discount = ($baseAmount * $coupon->value) / 100;
        } else {
            $discount = (float)$coupon->value;
        }

        $finalAmount = max(0, $baseAmount - $discount);

        return response()->json([
            'status' => 'success',
            'message' => 'Coupon applied successfully!',
            'data' => [
                'code' => $coupon->code,
                'description' => $coupon->description,
                'type' => $coupon->type,
                'value' => (float)$coupon->value,
                'discount' => round($discount, 2),
                'final_amount' => round($finalAmount, 2)
            ]
        ]);
    }
}
