<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Listing;
use App\Models\MarketplaceSetting;
use App\Models\PremiumPackage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FreeQuotaRotationTest extends TestCase
{
    use RefreshDatabase;

    private function payload(): array
    {
        $category = Category::firstOrCreate(['slug' => 'phones'], ['name' => 'Phones', 'is_active' => true]);

        return ['category_id' => $category->id, 'title' => 'Used phone', 'description' => 'Working phone',
            'price' => 100, 'city' => 'Kolkata', 'images' => ['https://example.com/phone.jpg'],
            'post_request_id' => (string) Str::uuid()];
    }

    public function test_free_quota_restores_exactly_thirty_days_after_exhaustion_without_charging_or_duplicating_a_post(): void
    {
        $user = User::factory()->create(['phone' => '9876543210']);
        Sanctum::actingAs($user);
        $this->postJson('/api/v1/listings', $this->payload())->assertCreated()->assertJsonPath('data.is_paid_ad', false);
        $this->assertNull($user->fresh()->free_quota_resets_at);
        $this->travel(5)->days();
        $lastFreePost = $this->payload();
        $this->postJson('/api/v1/listings', $lastFreePost)->assertCreated();
        $deadline = $user->fresh()->free_quota_resets_at;
        $this->assertEquals(now()->addDays(30)->timestamp, $deadline->timestamp);
        $this->postJson('/api/v1/listings', $lastFreePost)->assertCreated();
        $this->assertSame(2, $user->fresh()->free_ads_posted);
        $this->postJson('/api/v1/listings', $this->payload())->assertStatus(402);
        $this->travelTo($deadline->copy()->subSecond());
        $this->getJson('/api/v1/user/profile')->assertJsonPath('user.free_ads_posted', 2);
        $this->postJson('/api/v1/listings', $this->payload())->assertStatus(402);
        $this->travelTo($deadline);
        $this->getJson('/api/v1/user/profile')->assertJsonPath('user.free_ads_posted', 0)
            ->assertJsonPath('user.free_ads_limit', 2)->assertJsonPath('user.free_quota_resets_at', null);
        $this->postJson('/api/v1/listings', $this->payload())->assertCreated()->assertJsonPath('data.is_paid_ad', false);
        $this->assertSame(1, $user->fresh()->free_ads_posted);
        $this->assertDatabaseCount('wallet_transactions', 0);
    }

    public function test_admin_limit_changes_apply_immediately_without_resetting_usage_or_other_account_data(): void
    {
        $seller = User::factory()->create(['phone' => '9876543210', 'free_ads_posted' => 2, 'wallet_balance_paise' => 50000]);
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        $this->get('/admin/monetization')->assertOk()->assertSee('free_ads_limit');
        $this->post('/admin/monetization/free-quota', ['free_ads_limit' => 3])->assertRedirect();
        Sanctum::actingAs($seller);
        $this->getJson('/api/v1/user/profile')->assertJsonPath('user.free_ads_limit', 3)->assertJsonPath('user.free_ads_posted', 2);
        $this->postJson('/api/v1/listings', $this->payload())->assertCreated();
        $this->postJson('/api/v1/listings', $this->payload())->assertStatus(402);
        $this->assertSame(50000, $seller->fresh()->wallet_balance_paise);
        $this->assertFalse($seller->fresh()->is_premium);
    }

    public function test_only_admin_can_edit_limit_and_invalid_values_do_not_change_it(): void
    {
        $this->post('/admin/monetization/free-quota', ['free_ads_limit' => 999])->assertRedirect('/admin/login');
        $this->actingAs(User::factory()->create(['role' => 'user']), 'web');
        $this->post('/admin/monetization/free-quota', ['free_ads_limit' => 999])->assertRedirect('/admin/login');
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        foreach ([-1, 1.5, 1001, 'invalid'] as $value) {
            $this->post('/admin/monetization/free-quota', ['free_ads_limit' => $value])->assertSessionHasErrors('free_ads_limit');
        }
        $this->assertSame(2, MarketplaceSetting::freeAdLimit());
    }

    public function test_zero_limit_disables_free_posts_without_free_or_paid_benefits(): void
    {
        MarketplaceSetting::create(['key' => 'free_ads_limit', 'value' => 0]);
        Sanctum::actingAs(User::factory()->create(['phone' => '9876543210']));
        $this->postJson('/api/v1/listings', $this->payload())->assertStatus(402);
        $this->getJson('/api/v1/user/profile')->assertJsonPath('user.free_ads_limit', 0);
        $this->assertDatabaseCount('listings', 0);
    }

    public function test_existing_exhausted_users_restore_from_their_last_free_post_and_deleting_it_does_not_bypass_cooldown(): void
    {
        $user = User::factory()->create(['phone' => '9876543210', 'free_ads_posted' => 2]);
        $payload = $this->payload();
        unset($payload['images']);
        $listing = Listing::create(array_merge($payload, [
            'user_id' => $user->id, 'slug' => Str::uuid(), 'is_paid_ad' => false,
            'status' => 'active',
        ]));
        $listing->forceFill(['created_at' => now()->subDays(29)])->save();
        $listing->delete();
        Sanctum::actingAs($user);
        $this->getJson('/api/v1/user/profile')->assertJsonPath('user.free_ads_posted', 2);
        $this->assertEquals($listing->created_at->copy()->addDays(30)->timestamp, $user->fresh()->free_quota_resets_at->timestamp);
        $this->travel(1)->days();
        $this->postJson('/api/v1/listings', $this->payload())->assertCreated()->assertJsonPath('data.is_paid_ad', false);
        $this->assertSame(1, $user->fresh()->free_ads_posted);
    }

    public function test_premium_purchase_preserves_admin_free_limit_and_existing_cooldown(): void
    {
        MarketplaceSetting::create(['key' => 'free_ads_limit', 'value' => 3]);
        $deadline = now()->addDays(12)->startOfSecond();
        $user = User::factory()->create(['phone' => '9876543210', 'free_ads_posted' => 3,
            'free_quota_resets_at' => $deadline, 'wallet_balance_paise' => 10000]);
        $package = PremiumPackage::create(['key' => 'single', 'name' => 'Single ad', 'price' => 49,
            'ads_limit' => 1, 'duration_days' => 0, 'badge_enabled' => false, 'is_active' => true]);
        Sanctum::actingAs($user);
        $this->postJson('/api/v1/monetization/wallet', ['package_id' => $package->id, 'request_id' => (string) Str::uuid()])
            ->assertOk()->assertJsonPath('data.user.free_ads_limit', 3)->assertJsonPath('data.user.free_ads_posted', 3);
        $this->assertEquals($deadline->timestamp, $user->fresh()->free_quota_resets_at->timestamp);
        $this->postJson('/api/v1/listings', $this->payload())->assertCreated()->assertJsonPath('data.is_paid_ad', true);
        $this->assertSame(3, $user->fresh()->free_ads_posted);
        $this->assertEquals($deadline->timestamp, $user->fresh()->free_quota_resets_at->timestamp);
    }

    public function test_duplicate_phone_is_rejected_in_profile_and_registration_with_clear_message(): void
    {
        $existing = User::factory()->create(['phone' => '9876543210']);
        $seller = User::factory()->create(['phone' => '9876543211']);
        Sanctum::actingAs($seller);
        $this->postJson('/api/v1/user/profile', ['name' => 'Seller', 'phone' => '+919876543210'])
            ->assertUnprocessable()->assertJsonPath('errors.phone.0', 'This mobile number is already used by another account.');
        $this->assertSame('9876543211', $seller->fresh()->phone);
        $this->postJson('/api/v1/auth/register', ['name' => 'Another seller', 'email' => 'new@example.com', 'password' => 'password', 'phone' => $existing->phone])
            ->assertUnprocessable()->assertJsonPath('errors.phone.0', 'This mobile number is already used by another account.');

    }
}
