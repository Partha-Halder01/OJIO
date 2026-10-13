<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\ChatMessage;
use App\Models\ChatThread;
use App\Models\Coupon;
use App\Models\Listing;
use App\Models\PaymentOrder;
use App\Models\PremiumPackage;
use App\Models\User;
use App\Services\PaymentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MarketplaceFlowsTest extends TestCase
{
    use RefreshDatabase;

    private function user(array $attributes = []): User
    {
        return User::factory()->create(array_merge(['phone' => '9876543210'], $attributes));
    }

    private function package(array $attributes = []): PremiumPackage
    {
        return PremiumPackage::create(array_merge([
            'key' => 'per_ad', 'name' => 'Single Ad', 'price' => 49,
            'ads_limit' => 1, 'duration_days' => 0, 'badge_enabled' => false, 'is_active' => true,
        ], $attributes));
    }

    private function payload(): array
    {
        $category = Category::create(['name' => 'Mobiles', 'slug' => 'mobiles', 'is_active' => true]);

        return [
            'category_id' => $category->id, 'title' => 'Used phone', 'description' => 'Working phone in good condition.',
            'price' => 1000, 'city' => 'Kolkata', 'images' => ['https://example.com/phone.jpg'],
            'post_request_id' => (string) Str::uuid(), 'phone_number' => '9123456789',
        ];
    }

    private function listing(User $seller): Listing
    {
        $payload = $this->payload();
        unset($payload['images']);

        return Listing::create(array_merge($payload, ['user_id' => $seller->id, 'slug' => 'phone-'.Str::random(8), 'status' => 'active']));
    }

    public function test_guest_cannot_publish_or_access_wallet(): void
    {
        $this->postJson('/api/v1/listings', $this->payload())->assertUnauthorized();
        $this->getJson('/api/v1/wallet')->assertUnauthorized();
        $this->getJson('/api/v1/user/my-ads/updates')->assertUnauthorized();
        $this->postJson('/api/v1/user/my-ads/updates/read', ['updates' => []])->assertUnauthorized();
    }

    public function test_empty_chat_is_hidden_from_both_inboxes_until_first_message(): void
    {
        $seller = $this->user();
        $buyer = $this->user(['phone' => '9876543211']);
        $listing = $this->listing($seller);
        Sanctum::actingAs($buyer);
        $id = $this->postJson('/api/v1/chats/open', ['listing_id' => $listing->id])->assertOk()->json('data.thread_id');
        $this->getJson('/api/v1/chats')->assertOk()->assertJsonCount(0, 'data');
        Sanctum::actingAs($seller);
        $this->getJson('/api/v1/chats')->assertOk()->assertJsonCount(0, 'data');
        Sanctum::actingAs($buyer);
        $this->postJson('/api/v1/chats/send', ['thread_id' => $id, 'message' => '   '])->assertUnprocessable();
        $this->getJson('/api/v1/chats')->assertJsonCount(0, 'data');
        $this->postJson('/api/v1/chats/send', ['thread_id' => $id, 'message' => 'Available?'])->assertCreated();
        $this->getJson('/api/v1/chats')->assertJsonCount(1, 'data');
        Sanctum::actingAs($seller);
        $this->getJson('/api/v1/chats')->assertJsonCount(1, 'data')->assertJsonPath('data.0.unread_count', 1);
    }

    public function test_ad_update_acknowledgement_is_owner_scoped_and_preserves_newer_updates(): void
    {
        $seller = $this->user();
        $other = $this->user(['phone' => '9876543211']);
        $listing = $this->listing($seller);
        $listing->admin_update_version = 2;
        $listing->save();
        Sanctum::actingAs($other);
        $this->getJson('/api/v1/user/my-ads/updates')->assertJsonPath('has_updates', false);
        $this->postJson('/api/v1/user/my-ads/updates/read', ['updates' => [['id' => $listing->id, 'version' => 2]]])->assertOk();
        $this->assertEquals(0, $listing->fresh()->admin_seen_version);
        Sanctum::actingAs($seller);
        $this->getJson('/api/v1/user/my-ads')->assertJsonPath('data.0.admin_update_version', 2);
        $this->getJson('/api/v1/user/my-ads/updates')->assertJsonPath('has_updates', true);
        $this->postJson('/api/v1/user/my-ads/updates/read', ['updates' => [['id' => $listing->id, 'version' => 1]]])->assertJsonPath('has_updates', true);
        $this->postJson('/api/v1/user/my-ads/updates/read', ['updates' => [['id' => $listing->id, 'version' => 99]]])->assertJsonPath('has_updates', true);
        $this->postJson('/api/v1/user/my-ads/updates/read', ['updates' => [['id' => $listing->id, 'version' => 2]]])->assertJsonPath('has_updates', false);
        $this->postJson('/api/v1/user/my-ads/updates/read', ['updates' => [['id' => $listing->id, 'version' => 1]]])->assertJsonPath('has_updates', false);
        $this->assertEquals(2, $listing->fresh()->admin_seen_version);
    }

    public function test_free_post_uses_profile_phone_and_retries_do_not_consume_another_credit(): void
    {
        $user = $this->user();
        Sanctum::actingAs($user);
        $payload = $this->payload();
        $response = $this->postJson('/api/v1/listings', $payload)->assertCreated();
        $this->assertSame($user->phone, $response->json('data.phone_number'));
        $this->postJson('/api/v1/listings', $payload)->assertCreated()->assertJsonPath('data.id', $response->json('data.id'));
        $this->assertSame(1, $user->fresh()->free_ads_posted);
        $this->assertSame(1, Listing::count());
    }

    public function test_fabricated_payment_cannot_bypass_exhausted_quota(): void
    {
        $user = $this->user(['free_ads_posted' => 2]);
        Sanctum::actingAs($user);
        $payload = $this->payload();
        $payload['transaction_id'] = 'pay_fake';
        $this->postJson('/api/v1/listings', $payload)->assertStatus(402);
        $this->assertSame(0, Listing::count());
    }

    public function test_missing_profile_phone_prevents_posting_and_phone_is_normalized(): void
    {
        $user = $this->user(['phone' => null]);
        Sanctum::actingAs($user);
        $this->postJson('/api/v1/listings', $this->payload())->assertUnprocessable();
        $this->postJson('/api/v1/user/profile', ['name' => $user->name, 'phone' => '+919876543210'])->assertOk()->assertJsonPath('user.phone', '9876543210');
        $this->postJson('/api/v1/user/profile', ['name' => $user->name, 'phone' => '123'])->assertUnprocessable();
    }

    public function test_wallet_purchase_is_atomic_idempotent_and_consumes_paid_quota(): void
    {
        $user = $this->user(['wallet_balance_paise' => 10000, 'free_ads_posted' => 2]);
        Sanctum::actingAs($user);
        $package = $this->package();
        $checkout = ['package_id' => $package->id, 'request_id' => (string) Str::uuid()];
        $this->postJson('/api/v1/monetization/wallet', $checkout)->assertOk();
        $this->postJson('/api/v1/monetization/wallet', $checkout)->assertOk();
        $this->assertSame(5100, $user->fresh()->wallet_balance_paise);
        $this->assertSame(1, $user->fresh()->paid_ads_quota);
        $this->assertSame(1, DB::table('wallet_transactions')->count());
        $this->assertFalse($user->fresh()->has_diamond_badge);
        $this->postJson('/api/v1/listings', $this->payload())->assertCreated();
        $this->assertSame(0, $user->fresh()->paid_ads_quota);
        $this->postJson('/api/v1/listings', array_merge($this->payloadForExistingCategory(), ['post_request_id' => (string) Str::uuid()]))->assertStatus(402);
    }

    private function payloadForExistingCategory(): array
    {
        return ['category_id' => Category::first()->id, 'title' => 'Another phone', 'description' => 'Good condition', 'price' => 500, 'city' => 'Kolkata', 'images' => ['https://example.com/image.jpg']];
    }

    public function test_insufficient_wallet_balance_does_not_create_benefits_or_ledger_entries(): void
    {
        $user = $this->user(['wallet_balance_paise' => 1000]);
        Sanctum::actingAs($user);
        $package = $this->package();
        $this->postJson('/api/v1/monetization/wallet', ['package_id' => $package->id, 'request_id' => (string) Str::uuid()])->assertUnprocessable();
        $this->assertSame(1000, $user->fresh()->wallet_balance_paise);
        $this->assertSame(0, PaymentOrder::count());
        $this->assertSame(0, DB::table('wallet_transactions')->count());
    }

    public function test_topup_requires_signature_captured_payment_and_cannot_credit_twice(): void
    {
        config(['services.razorpay.key_id' => 'rzp_live_test_key', 'services.razorpay.key_secret' => 'test_secret']);
        Http::fake([
            'api.razorpay.com/v1/orders' => Http::response(['id' => 'order_test']),
            'api.razorpay.com/v1/orders/order_test' => Http::response(['id' => 'order_test', 'currency' => 'INR', 'amount' => 10000, 'amount_paid' => 10000, 'amount_due' => 0, 'status' => 'paid']),
            'api.razorpay.com/v1/payments/pay_test' => Http::response(['id' => 'pay_test', 'order_id' => 'order_test', 'currency' => 'INR', 'amount' => 10000, 'status' => 'captured', 'captured' => true]),
        ]);
        $user = $this->user();
        Sanctum::actingAs($user);
        $this->postJson('/api/v1/wallet/topup', ['amount_paise' => 10000])->assertOk()->assertJsonPath('data.order_id', 'order_test');
        $verification = ['razorpay_payment_id' => 'pay_test', 'razorpay_order_id' => 'order_test', 'razorpay_signature' => str_repeat('0', 64)];
        $this->postJson('/api/v1/monetization/verify-payment', $verification)->assertUnprocessable();
        $this->assertSame(0, $user->fresh()->wallet_balance_paise);
        $verification['razorpay_signature'] = hash_hmac('sha256', 'order_test|pay_test', 'test_secret');
        $this->postJson('/api/v1/monetization/verify-payment', $verification)->assertOk();
        $this->postJson('/api/v1/monetization/verify-payment', $verification)->assertOk();
        $this->assertSame(10000, $user->fresh()->wallet_balance_paise);
        $this->assertSame(1, DB::table('wallet_transactions')->count());
        $other = $this->user(['phone' => '9123456789']);
        Sanctum::actingAs($other);
        $this->postJson('/api/v1/monetization/verify-payment', $verification)->assertNotFound();
    }

    public function test_uncaptured_payment_and_wrong_amount_are_rejected(): void
    {
        config(['services.razorpay.key_id' => 'rzp_live_test_key', 'services.razorpay.key_secret' => 'test_secret']);
        $user = $this->user();
        Sanctum::actingAs($user);
        PaymentOrder::create(['user_id' => $user->id, 'purpose' => 'wallet_topup', 'amount_paise' => 10000, 'provider_order_id' => 'order_test']);
        foreach ([['status' => 'authorized', 'amount' => 10000], ['status' => 'captured', 'amount' => 5000]] as $payment) {
            Http::fake(['api.razorpay.com/*' => Http::response(array_merge(['id' => 'pay_test', 'order_id' => 'order_test', 'currency' => 'INR', 'captured' => true], $payment))]);
            $this->postJson('/api/v1/monetization/verify-payment', [
                'razorpay_payment_id' => 'pay_test', 'razorpay_order_id' => 'order_test',
                'razorpay_signature' => hash_hmac('sha256', 'order_test|pay_test', 'test_secret'),
            ])->assertUnprocessable();
        }
        $this->assertSame(0, $user->fresh()->wallet_balance_paise);
    }

    public function test_test_mode_opens_topup_and_premium_checkout_but_never_grants_real_benefits(): void
    {
        config(['services.razorpay.key_id' => 'rzp_test_example', 'services.razorpay.key_secret' => 'test_secret']);
        Http::fake([
            'api.razorpay.com/v1/orders' => Http::sequence()
                ->push(['id' => 'order_wallet_topup'])
                ->push(['id' => 'order_premium']),
        ]);
        $user = $this->user();
        Sanctum::actingAs($user);
        $package = $this->package(['badge_enabled' => true]);
        $topup = $this->postJson('/api/v1/wallet/topup', ['amount_paise' => 50000])
            ->assertOk()->assertJsonPath('data.order_id', 'order_wallet_topup')
            ->assertJsonPath('data.key_id', 'rzp_test_example')->assertJsonPath('data.status', 'pending');
        $premium = $this->postJson('/api/v1/monetization/order', ['package_id' => $package->id])
            ->assertOk()->assertJsonPath('data.order_id', 'order_premium')
            ->assertJsonPath('data.key_id', 'rzp_test_example')->assertJsonPath('data.status', 'pending');
        foreach ([$topup, $premium] as $response) {
            $order = PaymentOrder::findOrFail($response->json('data.id'));
            $this->postJson('/api/v1/monetization/verify-payment', [
                'razorpay_payment_id' => 'pay_test', 'razorpay_order_id' => $order->provider_order_id,
                'razorpay_signature' => hash_hmac('sha256', $order->provider_order_id.'|pay_test', 'test_secret'),
            ])->assertUnprocessable();
            $this->postJson('/api/v1/payments/'.$order->id.'/reconcile')->assertUnprocessable();
        }
        Http::assertSentCount(2);
        $this->assertSame(0, $user->fresh()->wallet_balance_paise);
        $this->assertFalse($user->fresh()->is_premium);
        $this->assertFalse($user->fresh()->has_diamond_badge);
        $this->assertDatabaseCount('wallet_transactions', 0);
        $this->assertSame(0, PaymentOrder::where('status', 'paid')->count());
    }

    private function fakeConfirmedGateway(array $paymentChanges = [], array $orderChanges = []): void
    {
        $payment = array_merge([
            'id' => 'pay_confirmed', 'order_id' => 'order_confirmed', 'status' => 'captured',
            'captured' => true, 'amount' => 50000, 'currency' => 'INR',
            'amount_refunded' => 0, 'refund_status' => null,
        ], $paymentChanges);
        Http::fake([
            'api.razorpay.com/v1/payments/pay_confirmed' => Http::response($payment),
            'api.razorpay.com/v1/orders/order_confirmed' => Http::response(array_merge([
                'id' => 'order_confirmed', 'status' => 'paid', 'currency' => 'INR',
                'amount' => 50000, 'amount_paid' => 50000, 'amount_due' => 0,
            ], $orderChanges)),
            'api.razorpay.com/v1/orders/order_confirmed/payments' => Http::response(['items' => [$payment]]),
        ]);
    }

    public function test_failed_authorized_refunded_and_mismatched_payments_never_credit_wallet_on_verify_or_reconcile(): void
    {
        config(['services.razorpay.key_id' => 'rzp_live_test_key', 'services.razorpay.key_secret' => 'test_secret']);
        $user = $this->user();
        Sanctum::actingAs($user);
        $order = PaymentOrder::create(['user_id' => $user->id, 'purpose' => 'wallet_topup', 'amount_paise' => 50000, 'provider_order_id' => 'order_confirmed']);
        foreach ([
            ['status' => 'failed'], ['status' => 'created'], ['status' => 'authorized'],
            ['captured' => false], ['currency' => 'USD'], ['amount' => 49999],
            ['order_id' => 'another_order'], ['id' => ''],
            ['amount_refunded' => 100], ['refund_status' => 'partial'],
        ] as $changes) {
            $this->fakeConfirmedGateway($changes);
            $this->postJson('/api/v1/monetization/verify-payment', [
                'razorpay_payment_id' => 'pay_confirmed', 'razorpay_order_id' => 'order_confirmed',
                'razorpay_signature' => hash_hmac('sha256', 'order_confirmed|pay_confirmed', 'test_secret'),
            ])->assertUnprocessable();
            $this->postJson('/api/v1/payments/'.$order->id.'/reconcile')->assertOk()->assertJsonPath('data.status', 'pending');
            $this->assertSame(0, $user->fresh()->wallet_balance_paise);
            $this->assertDatabaseCount('wallet_transactions', 0);
        }
    }

    public function test_captured_payment_requires_matching_fully_paid_provider_order(): void
    {
        config(['services.razorpay.key_id' => 'rzp_live_test_key', 'services.razorpay.key_secret' => 'test_secret']);
        $user = $this->user();
        Sanctum::actingAs($user);
        $order = PaymentOrder::create(['user_id' => $user->id, 'purpose' => 'wallet_topup', 'amount_paise' => 50000, 'provider_order_id' => 'order_confirmed']);
        foreach ([['status' => 'attempted'], ['amount_due' => 1], ['amount_paid' => 49999], ['id' => 'another_order'], ['currency' => 'USD']] as $changes) {
            $this->fakeConfirmedGateway([], $changes);
            $this->postJson('/api/v1/monetization/verify-payment', [
                'razorpay_payment_id' => 'pay_confirmed', 'razorpay_order_id' => 'order_confirmed',
                'razorpay_signature' => hash_hmac('sha256', 'order_confirmed|pay_confirmed', 'test_secret'),
            ])->assertUnprocessable();
            $this->postJson('/api/v1/payments/'.$order->id.'/reconcile')->assertJsonPath('data.status', 'pending');
        }
        $this->assertSame(0, $user->fresh()->wallet_balance_paise);
        $this->assertDatabaseCount('wallet_transactions', 0);
    }

    public function test_confirmed_live_payment_grants_premium_badge_once_and_never_adds_wallet_money(): void
    {
        config(['services.razorpay.key_id' => 'rzp_live_test_key', 'services.razorpay.key_secret' => 'test_secret']);
        $user = $this->user();
        Sanctum::actingAs($user);
        $package = $this->package(['price' => 500, 'badge_enabled' => true, 'ads_limit' => 5]);
        $order = app(PaymentService::class)->packageOrder($user, $package->id, null, 'razorpay');
        $order->update(['provider_order_id' => 'order_confirmed']);
        $this->fakeConfirmedGateway();
        $payload = ['razorpay_payment_id' => 'pay_confirmed', 'razorpay_order_id' => 'order_confirmed', 'razorpay_signature' => hash_hmac('sha256', 'order_confirmed|pay_confirmed', 'test_secret')];
        $this->postJson('/api/v1/monetization/verify-payment', $payload)->assertOk()->assertJsonPath('data.status', 'paid')->assertJsonPath('data.purpose', 'premium');
        $this->postJson('/api/v1/monetization/verify-payment', $payload)->assertOk();
        $this->assertTrue($user->fresh()->is_premium);
        $this->assertTrue($user->fresh()->has_diamond_badge);
        $this->assertSame(5, $user->fresh()->paid_ads_quota);
        $this->assertSame(0, $user->fresh()->wallet_balance_paise);
        $this->assertDatabaseCount('monetization_orders', 1);
        $this->assertDatabaseCount('wallet_transactions', 0);
    }

    public function test_wallet_purchase_requires_sufficient_balance_and_grants_badge_only_after_debit(): void
    {
        $user = $this->user(['wallet_balance_paise' => 50000]);
        Sanctum::actingAs($user);
        $package = $this->package(['price' => 500, 'badge_enabled' => true]);
        $request = ['package_id' => $package->id, 'request_id' => (string) Str::uuid()];
        $this->postJson('/api/v1/monetization/wallet', $request)->assertOk()->assertJsonPath('data.status', 'paid')->assertJsonPath('data.user.wallet_balance_paise', 0);
        $this->postJson('/api/v1/monetization/wallet', $request)->assertOk();
        $this->postJson('/api/v1/monetization/wallet', ['package_id' => $package->id, 'request_id' => (string) Str::uuid()])->assertUnprocessable();
        $this->assertSame(0, $user->fresh()->wallet_balance_paise);
        $this->assertTrue($user->fresh()->has_diamond_badge);
        $this->assertSame(1, $user->fresh()->paid_ads_quota);
        $this->assertDatabaseCount('wallet_transactions', 1);
        $this->assertDatabaseCount('monetization_orders', 1);
    }

    public function test_valid_full_discount_can_grant_complimentary_premium_without_a_gateway_payment(): void
    {
        Http::fake();
        $user = $this->user();
        Sanctum::actingAs($user);
        $package = $this->package();
        Coupon::create(['code' => 'FREE', 'type' => 'percentage', 'value' => 100, 'is_active' => true, 'show_in_app' => true]);
        $this->postJson('/api/v1/monetization/order', ['package_id' => $package->id, 'coupon_code' => 'FREE'])
            ->assertOk()->assertJsonPath('data.amount', 0)->assertJsonPath('data.status', 'paid')
            ->assertJsonPath('data.user.is_premium', true);
        Http::assertNothingSent();
        $this->assertSame(0, $user->fresh()->wallet_balance_paise);
        $this->assertDatabaseCount('wallet_transactions', 0);
    }

    public function test_package_price_and_discount_are_calculated_on_server(): void
    {
        $user = $this->user(['wallet_balance_paise' => 10000]);
        Sanctum::actingAs($user);
        $package = $this->package();
        Coupon::create(['code' => 'SAVE10', 'type' => 'percentage', 'value' => 10, 'is_active' => true, 'show_in_app' => true]);
        $this->postJson('/api/v1/monetization/wallet', ['package_id' => $package->id, 'coupon_code' => 'SAVE10', 'discount_amount' => 9999, 'request_id' => (string) Str::uuid()])->assertOk();
        $this->assertSame(5590, $user->fresh()->wallet_balance_paise);
        $this->assertSame(1, Coupon::first()->times_used);
    }

    public function test_expired_paid_credit_and_diamond_badge_do_not_bypass_quota(): void
    {
        $user = $this->user(['free_ads_posted' => 2, 'paid_ads_quota' => 5, 'has_diamond_badge' => true]);
        PaymentOrder::create(['user_id' => $user->id, 'purpose' => 'premium', 'provider' => 'wallet', 'amount_paise' => 1000, 'remaining_ads' => 5, 'expires_at' => now()->subDay(), 'status' => 'paid']);
        Sanctum::actingAs($user);
        $this->postJson('/api/v1/listings', $this->payload())->assertStatus(402);
    }

    public function test_chat_opens_same_thread_and_only_participants_can_read_or_send(): void
    {
        $seller = $this->user();
        $buyer = $this->user(['phone' => '9123456789']);
        $stranger = $this->user(['phone' => '9234567890']);
        $listing = $this->listing($seller);
        Sanctum::actingAs($buyer);
        $threadId = $this->postJson('/api/v1/chats/open', ['listing_id' => $listing->id])->assertOk()->json('data.thread_id');
        $this->postJson('/api/v1/chats/open', ['listing_id' => $listing->id])->assertJsonPath('data.thread_id', $threadId);
        $this->postJson('/api/v1/chats/send', ['thread_id' => $threadId, 'message' => 'Is this available?'])->assertCreated();
        Sanctum::actingAs($seller);
        $this->getJson('/api/v1/chats')->assertOk()->assertJsonPath('data.0.unread_count', 1);
        $this->getJson('/api/v1/chats/'.$threadId.'/messages')->assertOk()->assertJsonPath('messages.0.is_read', true);
        $this->postJson('/api/v1/chats/send', ['thread_id' => $threadId, 'message' => 'Yes, available.'])->assertCreated();
        $this->postJson('/api/v1/chats/send', ['listing_id' => $listing->id, 'message' => 'Wrong buyer'])->assertUnprocessable();
        Sanctum::actingAs($stranger);
        $this->getJson('/api/v1/chats/'.$threadId.'/messages')->assertNotFound();
        $this->postJson('/api/v1/chats/send', ['thread_id' => $threadId, 'message' => 'Intrusion'])->assertForbidden();
        $this->assertSame(2, ChatMessage::count());
        $this->assertSame(1, ChatThread::count());
    }

    public function test_hidden_phone_is_not_exposed_by_listing_api(): void
    {
        $seller = $this->user();
        $listing = $this->listing($seller);
        $listing->update(['hide_phone' => true, 'phone_number' => $seller->phone]);
        $response = $this->getJson('/api/v1/listings/'.$listing->id)->assertOk();
        $response->assertJsonPath('data.phone_number', null);
        $this->assertArrayNotHasKey('phone', $response->json('data.user'));
    }

    public function test_google_login_does_not_accept_unverified_email_claim(): void
    {
        $this->postJson('/api/v1/auth/firebase-login', ['email' => 'someone@example.com', 'firebase_uid' => 'fake'])->assertUnprocessable();
        $this->postJson('/api/v1/auth/firebase-login', ['id_token' => 'fake'])->assertUnauthorized();
        $this->assertSame(0, User::count());
    }

    public function test_blocked_user_cannot_access_wallet_or_chats(): void
    {
        $user = $this->user(['is_blocked' => true]);
        Sanctum::actingAs($user);
        $this->getJson('/api/v1/wallet')->assertForbidden();
        $this->getJson('/api/v1/chats')->assertForbidden();
    }

    public function test_admin_package_and_landing_share_app_data(): void
    {
        $package = $this->package();
        $seller = $this->user();
        $this->listing($seller);
        $package->update(['price' => 79]);
        $this->getJson('/api/v1/packages')->assertOk()->assertJsonPath('data.0.price', '79.00');
        $this->get('/')->assertOk()->assertSee('Used phone');
        $this->assertSame(0, DB::table('monetization_orders')->count());
    }

    public function test_browser_reverse_geocoding_returns_city_area_and_hierarchy(): void
    {
        Http::fake(['photon.komoot.io/*' => Http::response([
            'features' => [['properties' => ['city' => 'Kolkata', 'district' => 'Salt Lake', 'county' => 'North 24 Parganas'],
                'geometry' => ['coordinates' => [88.3639, 22.5726]]]],
        ])]);
        $this->getJson('/api/v1/locations/reverse?latitude=22.5726&longitude=88.3639')->assertOk()->assertJsonPath('data.city', 'Kolkata')->assertJsonPath('data.locality', 'Salt Lake');
        $this->getJson('/api/v1/locations/reverse?latitude=999&longitude=88')->assertUnprocessable();
    }

    public function test_reverse_geocoding_uses_nearest_address_not_a_nearby_village(): void
    {
        Http::preventStrayRequests();
        Http::fake(['photon.komoot.io/*' => Http::response(['features' => [
            ['properties' => ['name' => 'Janwada', 'osm_key' => 'place', 'osm_value' => 'village'],
                'geometry' => ['coordinates' => [78.27, 17.43]]],
            ['properties' => ['city' => 'Hyderabad', 'suburb' => 'Nallagandla', 'district' => '', 'name' => 'A nearby shop'],
                'geometry' => ['coordinates' => [78.304068, 17.478131]]],
        ]])]);
        $this->getJson('/api/v1/locations/reverse?latitude=17.4781306&longitude=78.3040678')
            ->assertOk()->assertJsonPath('data.city', 'Hyderabad')->assertJsonPath('data.locality', 'Nallagandla');
        Http::assertSent(fn ($request): bool => $request['lat'] === 17.4781306 && $request['lon'] === 78.3040678
            && $request['radius'] === 0.5 && $request['limit'] === 5);
    }

    public function test_reverse_geocoding_does_not_use_a_shop_or_road_name_as_an_area(): void
    {
        Http::preventStrayRequests();
        Http::fake(['photon.komoot.io/*' => Http::response(['features' => [
            ['properties' => ['city' => 'Hyderabad', 'district' => '', 'name' => 'Janwada Road', 'osm_key' => 'highway'],
                'geometry' => ['coordinates' => [78.304068, 17.478131]]],
        ]])]);
        $this->getJson('/api/v1/locations/reverse?latitude=17.4781306&longitude=78.3040678')
            ->assertOk()->assertJsonPath('data.locality', '')->assertJsonMissing(['Janwada Road']);
    }

    public function test_reverse_geocoding_rejects_distant_or_unlocated_results(): void
    {
        Http::preventStrayRequests();
        Http::fake(['photon.komoot.io/*' => Http::response(['features' => [
            ['properties' => ['city' => 'Hyderabad', 'district' => 'Janwada'],
                'geometry' => ['coordinates' => [78.27, 17.43]]],
            ['properties' => ['city' => 'Hyderabad', 'district' => 'Unknown location']],
        ]])]);
        $this->getJson('/api/v1/locations/reverse?latitude=17.4781306&longitude=78.3040678')->assertUnprocessable();
    }

    public function test_paid_grant_is_authoritative_even_if_user_summary_is_stale(): void
    {
        $user = $this->user(['free_ads_posted' => 2, 'paid_ads_quota' => 0]);
        PaymentOrder::create(['user_id' => $user->id, 'purpose' => 'premium', 'provider' => 'wallet', 'amount_paise' => 4900, 'remaining_ads' => 1, 'status' => 'paid']);
        Sanctum::actingAs($user);
        $this->postJson('/api/v1/listings', $this->payload())->assertCreated();
        $this->assertSame(0, PaymentOrder::first()->remaining_ads);
        $this->postJson('/api/v1/listings', $this->payloadForExistingCategory())->assertStatus(402);
    }

    public function test_interrupted_topup_can_be_recovered_without_trusting_client_payment_data(): void
    {
        config(['services.razorpay.key_id' => 'rzp_live_test_key', 'services.razorpay.key_secret' => 'test_secret']);
        Http::fake([
            'api.razorpay.com/v1/orders/order_recover' => Http::response(['id' => 'order_recover', 'currency' => 'INR', 'amount' => 10000, 'amount_paid' => 10000, 'amount_due' => 0, 'status' => 'paid']),
            'api.razorpay.com/v1/orders/order_recover/payments' => Http::response(['items' => [[
                'id' => 'pay_recover', 'order_id' => 'order_recover', 'status' => 'captured', 'captured' => true, 'currency' => 'INR', 'amount' => 10000,
            ]]]),
        ]);
        $user = $this->user();
        Sanctum::actingAs($user);
        $order = PaymentOrder::create(['user_id' => $user->id, 'purpose' => 'wallet_topup', 'amount_paise' => 10000, 'provider_order_id' => 'order_recover']);
        $this->postJson('/api/v1/payments/'.$order->id.'/reconcile')->assertOk()->assertJsonPath('data.status', 'paid');
        $this->postJson('/api/v1/payments/'.$order->id.'/reconcile')->assertOk();
        $this->assertSame(10000, $user->fresh()->wallet_balance_paise);
        $this->assertSame(1, DB::table('wallet_transactions')->count());
    }

    public function test_google_login_uses_signed_identity_and_rejects_wrong_audience(): void
    {
        $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA, 'config' => base_path('tests/Fixtures/openssl.cnf')]);
        $this->assertNotFalse($key);
        $publicKey = openssl_pkey_get_details($key)['key'];
        Http::fake(['www.googleapis.com/oauth2/v1/certs' => Http::response(['test_key' => $publicKey])]);
        $encode = static fn ($value) => rtrim(strtr(base64_encode(json_encode($value)), '+/', '-_'), '=');
        $claims = ['iss' => 'https://accounts.google.com', 'aud' => config('services.google.client_id'), 'sub' => 'google_user',
            'exp' => time() + 3600, 'email' => 'google@example.com', 'email_verified' => true, 'name' => 'Google User'];
        $makeToken = function (array $claims) use ($key, $encode) {
            $body = $encode(['alg' => 'RS256', 'kid' => 'test_key']).'.'.$encode($claims);
            openssl_sign($body, $signature, $key, OPENSSL_ALGO_SHA256);

            return $body.'.'.rtrim(strtr(base64_encode($signature), '+/', '-_'), '=');
        };
        $this->postJson('/api/v1/auth/firebase-login', ['id_token' => $makeToken($claims), 'email' => 'imposter@example.com', 'phone' => '9876543210'])
            ->assertOk()->assertJsonPath('user.email', 'google@example.com')->assertJsonPath('user.phone', null);
        $claims['aud'] = 'another_app';
        $this->postJson('/api/v1/auth/firebase-login', ['id_token' => $makeToken($claims)])->assertUnauthorized();
        $this->assertSame(1, User::count());
    }

    public function test_admin_sees_wallet_ledger_and_package_revenue_without_double_counting_topups(): void
    {
        $user = $this->user(['wallet_balance_paise' => 10000]);
        Sanctum::actingAs($user);
        $package = $this->package();
        $this->postJson('/api/v1/monetization/wallet', ['package_id' => $package->id, 'request_id' => (string) Str::uuid()])->assertOk();
        $admin = $this->user(['phone' => '9234567890', 'role' => 'admin']);
        $this->actingAs($admin, 'web')->get('/admin/monetization')->assertOk()->assertSee('Wallet activity')->assertSee('Single Ad');
        $this->assertEquals(49, DB::table('monetization_orders')->sum('amount'));
    }
}
