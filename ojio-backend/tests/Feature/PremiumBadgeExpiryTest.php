<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Listing;
use App\Models\PaymentOrder;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PremiumBadgeExpiryTest extends TestCase
{
    use RefreshDatabase;

    private function purchase(User $user, ?string $expires, bool $diamond = true, string $status = 'paid'): PaymentOrder
    {
        return PaymentOrder::create([
            'user_id' => $user->id, 'purpose' => 'premium', 'provider' => 'wallet',
            'amount_paise' => 59900, 'status' => $status, 'remaining_ads' => 5,
            'expires_at' => $expires, 'benefits' => ['badge_enabled' => $diamond],
        ]);
    }

    public function test_profile_and_listing_badges_expire_without_deleting_ads_or_changing_wallet(): void
    {
        $this->freezeTime();
        $user = User::factory()->create(['is_premium' => true, 'has_diamond_badge' => true,
            'premium_until' => now()->addDay(), 'wallet_balance_paise' => 50000]);
        $order = $this->purchase($user, now()->addSecond()->toISOString());
        $category = Category::create(['name' => 'Phone', 'slug' => 'phone']);
        $listing = Listing::create(['user_id' => $user->id, 'category_id' => $category->id,
            'title' => 'Phone', 'slug' => Str::uuid(), 'description' => 'Phone', 'price' => 1000,
            'city' => 'Kolkata', 'status' => 'active']);
        Sanctum::actingAs($user);
        $this->getJson('/api/v1/user/profile')->assertJsonPath('user.has_diamond_badge', true);
        $this->getJson('/api/v1/listings')->assertJsonPath('data.data.0.user.has_diamond_badge', true)
            ->assertJsonMissingPath('data.data.0.user.paid_premium_orders');
        $this->travel(1)->seconds();
        $this->getJson('/api/v1/user/profile')->assertJsonPath('user.is_premium', false)
            ->assertJsonPath('user.has_diamond_badge', false)->assertJsonPath('user.paid_ads_quota', 0);
        $this->getJson('/api/v1/listings/'.$listing->id)->assertJsonPath('data.user.has_diamond_badge', false);
        $this->assertSame('active', $listing->fresh()->status);
        $this->assertSame(50000, $user->fresh()->wallet_balance_paise);
        $this->assertSame('paid', $order->fresh()->status);
    }

    public function test_active_diamond_package_survives_a_newer_non_diamond_purchase(): void
    {
        $this->freezeTime();
        $user = User::factory()->create(['has_diamond_badge' => false]);
        $diamond = $this->purchase($user, now()->addDay()->toISOString());
        $this->purchase($user, now()->addDays(5)->toISOString(), false);
        $status = $user->premiumStatus();
        $this->assertTrue($status['has_diamond_badge']);
        $this->assertSame($diamond->expires_at->toISOString(), $status['diamond_badge_until']);
        $this->assertSame(now()->addDays(5)->startOfSecond()->toISOString(), $status['premium_until']);
        $this->travel(1)->days();
        $this->assertFalse($user->premiumStatus()['has_diamond_badge']);
        $this->assertTrue($user->premiumStatus()['is_premium']);
    }

    public function test_pending_failed_and_expired_orders_do_not_grant_badges_but_renewal_does(): void
    {
        $user = User::factory()->create(['is_premium' => true, 'has_diamond_badge' => true]);
        $this->purchase($user, now()->addDay()->toISOString(), true, 'pending');
        $this->purchase($user, now()->addDay()->toISOString(), true, 'failed');
        $this->purchase($user, now()->subDay()->toISOString());
        $this->assertFalse($user->premiumStatus()['is_premium']);
        $this->purchase($user, now()->addDays(30)->toISOString());
        $user->unsetRelation('paidPremiumOrders');
        $this->assertTrue($user->premiumStatus()['has_diamond_badge']);
    }

    public function test_confirmed_non_expiring_package_is_supported_and_unpaid_flags_are_not(): void
    {
        $user = User::factory()->create(['is_premium' => true, 'has_diamond_badge' => true]);
        $this->assertFalse($user->premiumStatus()['is_premium']);
        $this->purchase($user, null, false);
        $user->unsetRelation('paidPremiumOrders');
        $this->assertTrue($user->premiumStatus()['is_premium']);
        $this->assertFalse($user->premiumStatus()['has_diamond_badge']);
        $this->assertNull($user->premiumStatus()['premium_until']);
    }
}
