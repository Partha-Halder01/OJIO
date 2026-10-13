<?php

namespace App\Services;

use App\Models\Coupon;
use App\Models\MonetizationOrder;
use App\Models\PaymentOrder;
use App\Models\PremiumPackage;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;

class PaymentService
{
    public function packageOrder(User $user, int $packageId, ?string $couponCode, string $provider, ?string $requestId = null): PaymentOrder
    {
        $couponCode = $couponCode ? strtoupper(trim($couponCode)) : null;
        $package = PremiumPackage::where('is_active', true)->findOrFail($packageId);
        $amount = (int) round((float) $package->price * 100);
        $discount = 0;
        if ($couponCode) {
            $coupon = Coupon::valid()->forApp()->where('code', $couponCode)->first();
            if (! $coupon) {
                throw ValidationException::withMessages(['coupon_code' => 'This coupon is unavailable.']);
            }
            $discount = min($amount, max(0, (int) round($coupon->type === 'percentage'
                ? $amount * $coupon->value / 100 : $coupon->value * 100)));
        }

        return PaymentOrder::create([
            'user_id' => $user->id, 'package_id' => $package->id, 'purpose' => 'premium',
            'provider' => $provider, 'request_id' => $requestId,
            'amount_paise' => $amount - $discount, 'discount_paise' => $discount,
            'coupon_code' => $couponCode,
            'benefits' => $package->only(['key', 'name', 'ads_limit', 'duration_days', 'badge_enabled']),
        ]);
    }

    public function createRazorpayOrder(PaymentOrder $order): array
    {
        if ($order->amount_paise > 0) {
            abort_unless(config('services.razorpay.key_id') && config('services.razorpay.key_secret'), 503, 'Payments are not configured.');
            $result = Http::withBasicAuth(config('services.razorpay.key_id'), config('services.razorpay.key_secret'))
                ->timeout(20)->post('https://api.razorpay.com/v1/orders', [
                    'amount' => $order->amount_paise, 'currency' => 'INR', 'receipt' => 'ojio_'.$order->id,
                ])->throw()->json();
            $order->update(['provider_order_id' => $result['id']]);
        } else {
            abort_unless($order->purpose === 'premium', 422, 'Invalid payment amount.');
            $this->settle($order, null);
        }

        return [
            'id' => $order->id, 'order_id' => $order->provider_order_id,
            'amount' => $order->amount_paise, 'currency' => 'INR',
            'key_id' => config('services.razorpay.key_id'), 'status' => $order->fresh()->status,
            'purpose' => $order->purpose,
            'user' => $order->fresh()->status === 'paid' ? User::findOrFail($order->user_id) : null,
        ];
    }

    private function requireLiveRazorpay(): void
    {
        $key = (string) config('services.razorpay.key_id');
        abort_unless($key && config('services.razorpay.key_secret'), 503, 'Payments are not configured.');
        if (! str_starts_with($key, 'rzp_live_')) {
            throw ValidationException::withMessages([
                'payment' => 'This was a test checkout, not a real payment. No wallet money or premium benefits were added.',
            ]);
        }
    }

    private function isCapturedPayment(PaymentOrder $order, array $payment, ?string $paymentId = null): bool
    {
        return is_string($payment['id'] ?? null) && $payment['id'] !== ''
            && ($paymentId === null || $payment['id'] === $paymentId)
            && ($payment['order_id'] ?? '') === $order->provider_order_id
            && ($payment['currency'] ?? '') === 'INR'
            && (int) ($payment['amount'] ?? -1) === $order->amount_paise
            && ($payment['status'] ?? '') === 'captured'
            && ($payment['captured'] ?? false) === true
            && (int) ($payment['amount_refunded'] ?? 0) === 0
            && ($payment['refund_status'] ?? null) === null;
    }

    private function isPaidProviderOrder(PaymentOrder $order): bool
    {
        $result = Http::withBasicAuth(config('services.razorpay.key_id'), config('services.razorpay.key_secret'))
            ->timeout(20)->get('https://api.razorpay.com/v1/orders/'.$order->provider_order_id)->throw()->json();

        return ($result['id'] ?? '') === $order->provider_order_id
            && ($result['status'] ?? '') === 'paid' && ($result['currency'] ?? '') === 'INR'
            && (int) ($result['amount'] ?? -1) === $order->amount_paise
            && (int) ($result['amount_paid'] ?? -1) === $order->amount_paise
            && (int) ($result['amount_due'] ?? -1) === 0;
    }

    public function verify(PaymentOrder $order, string $paymentId, string $signature): void
    {
        $this->requireLiveRazorpay();
        $secret = config('services.razorpay.key_secret');
        abort_unless($secret && $order->provider === 'razorpay' && $order->provider_order_id, 422, 'Invalid payment order.');
        $expected = hash_hmac('sha256', $order->provider_order_id.'|'.$paymentId, $secret);
        abort_unless(hash_equals($expected, $signature), 422, 'Invalid payment signature.');
        $payment = Http::withBasicAuth(config('services.razorpay.key_id'), $secret)->timeout(20)
            ->get('https://api.razorpay.com/v1/payments/'.$paymentId)->throw()->json();
        abort_unless($this->isCapturedPayment($order, $payment, $paymentId)
            && $this->isPaidProviderOrder($order), 422, 'Payment has not been confirmed. No wallet money or premium benefits were added. Check payment status before paying again.');
        $this->settle($order, $paymentId);
    }

    public function reconcile(PaymentOrder $order): void
    {
        if ($order->provider === 'wallet' || $order->amount_paise === 0) {
            return;
        }
        $this->requireLiveRazorpay();
        abort_unless($order->provider === 'razorpay' && $order->provider_order_id, 422, 'Invalid payment order.');
        if (! $this->isPaidProviderOrder($order)) {
            abort_if($order->status === 'paid', 422, 'Payment status could not be confirmed. Please contact support.');

            return;
        }
        $result = Http::withBasicAuth(config('services.razorpay.key_id'), config('services.razorpay.key_secret'))
            ->timeout(15)->get('https://api.razorpay.com/v1/orders/'.$order->provider_order_id.'/payments')->throw()->json();
        foreach ($result['items'] ?? [] as $payment) {
            if ($this->isCapturedPayment($order, $payment)) {
                $this->settle($order, $payment['id']);

                return;
            }
        }
        abort_if($order->status === 'paid', 422, 'Payment status could not be confirmed. Please contact support.');
    }

    public function payWithWallet(PaymentOrder $order): void
    {
        abort_unless($order->provider === 'wallet' && $order->purpose === 'premium', 422, 'Invalid wallet purchase.');
        $this->settle($order, null);
    }

    private function settle(PaymentOrder $order, ?string $paymentId): void
    {
        DB::transaction(function () use ($order, $paymentId) {
            $order = PaymentOrder::lockForUpdate()->findOrFail($order->id);
            if ($order->status === 'paid') {
                abort_if($paymentId !== null && $order->provider_payment_id !== $paymentId, 422, 'This order has already been paid using another payment.');

                return;
            }
            $user = User::lockForUpdate()->findOrFail($order->user_id);
            if ($order->purpose === 'wallet_topup') {
                $user->wallet_balance_paise += $order->amount_paise;
                $description = 'Wallet top-up';
                $delta = $order->amount_paise;
            } else {
                if ($order->provider === 'wallet') {
                    abort_if($user->wallet_balance_paise < $order->amount_paise, 422, 'Insufficient wallet balance.');
                    $user->wallet_balance_paise -= $order->amount_paise;
                }
                $benefits = $order->benefits;
                $duration = (int) ($benefits['duration_days'] ?? 0);
                if ($user->paid_quota_until?->isPast()) {
                    $user->paid_ads_quota = 0;
                }
                $remainingAds = (int) $benefits['ads_limit'] > 0 ? (int) $benefits['ads_limit'] : 999999;
                $order->remaining_ads = $remainingAds;
                $order->expires_at = $duration > 0 ? now()->addDays($duration) : null;
                $order->save();
                $user->paid_ads_quota = $remainingAds + (int) PaymentOrder::where('user_id', $user->id)
                    ->where('purpose', 'premium')->where('status', 'paid')->where('id', '!=', $order->id)
                    ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))->sum('remaining_ads');
                $user->paid_quota_until = $duration > 0 ? now()->addDays($duration) : null;
                $user->is_premium = true;
                $user->has_diamond_badge = (bool) $benefits['badge_enabled'];
                $user->badge_type = $benefits['badge_enabled'] ? 'diamond' : ((int) $benefits['ads_limit'] > 1 ? 'silver' : 'bronze');
                $user->premium_until = $duration > 0 ? now()->addDays($duration) : null;
                MonetizationOrder::create([
                    'user_id' => $user->id, 'amount' => $order->amount_paise / 100, 'currency' => 'INR',
                    'payment_provider' => $order->provider, 'transaction_id' => $paymentId ?? 'wallet_'.$order->id,
                    'payment_status' => 'paid', 'ad_type' => $benefits['key'],
                    'coupon_code' => $order->coupon_code, 'discount_amount' => $order->discount_paise / 100,
                ]);
                if ($order->coupon_code) {
                    Coupon::where('code', $order->coupon_code)->increment('times_used');
                }
                $description = $benefits['name'];
                $delta = -$order->amount_paise;
            }
            $user->save();
            if ($order->purpose === 'wallet_topup' || $order->provider === 'wallet') {
                DB::table('wallet_transactions')->insert([
                    'user_id' => $user->id, 'payment_order_id' => $order->id,
                    'amount_paise' => $delta, 'balance_paise' => $user->wallet_balance_paise,
                    'description' => $description, 'created_at' => now(), 'updated_at' => now(),
                ]);
            }
            $order->update(['status' => 'paid', 'provider_payment_id' => $paymentId]);
            app(PushNotificationService::class)->notify(
                (int) $user->id, 'payment', 'Payment confirmed',
                $order->purpose === 'wallet_topup' ? 'Your wallet top-up has been confirmed.' : 'Your premium package is active.',
                ['order_id' => (string) $order->id, 'event_id' => 'payment_'.$order->id],
            );
        });
    }
}
