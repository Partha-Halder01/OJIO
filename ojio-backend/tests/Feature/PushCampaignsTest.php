<?php

namespace Tests\Feature;

use App\Jobs\BroadcastCouponNotification;
use App\Jobs\SendPushNotification;
use App\Models\Coupon;
use App\Models\MarketplaceSetting;
use App\Models\PushDevice;
use App\Models\User;
use App\Services\FcmService;
use App\Services\PushCampaignService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Tests\TestCase;

class PushCampaignsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.fcm.enabled' => true, 'services.fcm.queue_connection' => 'database']);
        Queue::fake();
        Http::preventStrayRequests();
    }

    private function coupon(array $attributes = []): Coupon
    {
        return Coupon::create(array_merge([
            'code' => 'SAVE10', 'description' => 'Test offer', 'type' => 'percentage',
            'value' => 10, 'is_active' => true, 'show_in_app' => true, 'times_used' => 0,
        ], $attributes));
    }

    public function test_registration_saves_explicit_consent_and_welcomes_once(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $payload = ['device_key' => str_repeat('a', 64), 'token' => str_repeat('t', 80), 'chat_enabled' => true];
        $this->postJson('/api/v1/user/push-device', $payload)->assertOk();
        $this->assertFalse(PushDevice::firstOrFail()->marketing_enabled);
        $this->postJson('/api/v1/user/push-device', [...$payload, 'marketing_enabled' => true])->assertOk();
        $this->assertTrue(PushDevice::firstOrFail()->marketing_enabled);
        $this->postJson('/api/v1/user/push-device', [...$payload, 'marketing_enabled' => false])->assertOk();
        Queue::assertPushed(SendPushNotification::class, 1);
        Queue::assertPushed(SendPushNotification::class, fn ($job) => $job->data['type'] === 'welcome');
        $this->assertFalse($user->fresh()->welcome_push_pending);
        $this->assertArrayNotHasKey('welcome_push_pending', $user->fresh()->toArray());
        $this->postJson('/api/v1/user/push-device', [...$payload, 'marketing_enabled' => 'bad'])->assertUnprocessable();
    }

    public function test_disabled_fcm_or_no_device_preserves_welcome_for_later(): void
    {
        $user = User::factory()->create();
        $service = app(PushCampaignService::class);
        $service->welcome($user->id);
        $this->assertTrue($user->fresh()->welcome_push_pending);
        PushDevice::factory()->create(['user_id' => $user->id]);
        config(['services.fcm.enabled' => false]);
        $service->welcome($user->id);
        $this->assertTrue($user->fresh()->welcome_push_pending);
        Queue::assertNothingPushed();
    }

    public function test_existing_users_are_not_welcomed_again(): void
    {
        $user = User::factory()->create();
        DB::table('users')->where('id', $user->id)->update(['welcome_push_pending' => false]);
        PushDevice::factory()->create(['user_id' => $user->id]);
        app(PushCampaignService::class)->welcome($user->id);
        Queue::assertNothingPushed();
    }

    public function test_coupon_broadcast_only_targets_opted_in_unblocked_users_once(): void
    {
        $device = PushDevice::factory()->create(['marketing_enabled' => true]);
        PushDevice::factory()->create(['user_id' => $device->user_id, 'marketing_enabled' => false]);
        PushDevice::factory()->create(['marketing_enabled' => false]);
        PushDevice::factory()->create(['user_id' => User::factory()->create(['is_blocked' => true])->id, 'marketing_enabled' => true]);
        $job = new BroadcastCouponNotification($this->coupon()->id);
        $job->handle(app(PushCampaignService::class));
        $job->handle(app(PushCampaignService::class));
        Queue::assertPushed(SendPushNotification::class, 1);
        Queue::assertPushed(SendPushNotification::class, fn ($push) => $push->deviceId === $device->id && $push->data['type'] === 'coupon');
        $this->assertDatabaseCount('push_campaign_receipts', 1);
    }

    public function test_ineligible_coupons_are_not_announced(): void
    {
        PushDevice::factory()->create(['marketing_enabled' => true]);
        foreach ([['is_active' => false], ['show_in_app' => false], ['expires_at' => now()->subMinute()], ['usage_limit' => 1, 'times_used' => 1]] as $index => $attributes) {
            $coupon = $this->coupon([...$attributes, 'code' => 'SAVE'.$index]);
            (new BroadcastCouponNotification($coupon->id))->handle(app(PushCampaignService::class));
        }
        Queue::assertNothingPushed();
    }

    public function test_admin_creation_queues_only_new_public_active_coupon(): void
    {
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        $payload = ['code' => 'NEW', 'description' => 'Offer', 'type' => 'fixed', 'value' => 10, 'show_in_app' => true];
        $this->post('/admin/coupons', $payload)->assertRedirect();
        Queue::assertPushed(BroadcastCouponNotification::class, 1);
        $this->post('/admin/coupons', [...$payload, 'code' => 'LANDING', 'show_in_app' => null])->assertRedirect();
        Queue::assertPushed(BroadcastCouponNotification::class, 1);
    }

    public function test_reminder_command_has_seven_day_limit_and_requires_free_quota(): void
    {
        $user = User::factory()->create(['created_at' => now()->subDays(8)]);
        PushDevice::factory()->create(['user_id' => $user->id, 'marketing_enabled' => true]);
        $this->artisan('fcm:posting-reminders')->assertSuccessful();
        $this->artisan('fcm:posting-reminders')->assertSuccessful();
        Queue::assertPushed(SendPushNotification::class, 1);
        $this->travel(6)->days();
        $this->artisan('fcm:posting-reminders')->assertSuccessful();
        Queue::assertPushed(SendPushNotification::class, 1);
        $this->travel(1)->days();
        $this->artisan('fcm:posting-reminders')->assertSuccessful();
        Queue::assertPushed(SendPushNotification::class, 2);
        $user->fresh()->update(['free_ads_posted' => MarketplaceSetting::freeAdLimit(), 'free_quota_resets_at' => now()->addDays(30)]);
        $this->travel(7)->days();
        $this->artisan('fcm:posting-reminders')->assertSuccessful();
        Queue::assertPushed(SendPushNotification::class, 2);
    }

    public function test_reminder_excludes_new_opted_out_and_blocked_users(): void
    {
        foreach ([['created_at' => now()], ['created_at' => now()->subDays(8), 'is_blocked' => true]] as $attributes) {
            PushDevice::factory()->create(['user_id' => User::factory()->create($attributes)->id, 'marketing_enabled' => true]);
        }
        PushDevice::factory()->create(['user_id' => User::factory()->create(['created_at' => now()->subDays(8)])->id, 'marketing_enabled' => false]);
        $this->artisan('fcm:posting-reminders')->assertSuccessful();
        Queue::assertNothingPushed();
    }

    public function test_delivery_rechecks_opt_out_coupon_validity_and_remaining_quota(): void
    {
        $device = PushDevice::factory()->create(['marketing_enabled' => true]);
        $coupon = $this->coupon();
        $job = new SendPushNotification($device->id, $device->user_id, $device->token_hash, 'Offer', 'Offer', ['type' => 'coupon', 'coupon_id' => (string) $coupon->id]);
        $fcm = $this->mock(FcmService::class);
        $fcm->shouldNotReceive('send');
        $device->update(['marketing_enabled' => false]);
        $job->handle($fcm);
        $device->update(['marketing_enabled' => true]);
        $coupon->update(['is_active' => false]);
        $job->handle($fcm);
        $device->user->update(['free_ads_posted' => MarketplaceSetting::freeAdLimit(), 'free_quota_resets_at' => now()->addDays(30)]);
        $job->data = ['type' => 'post_reminder'];
        $job->handle($fcm);
    }

    public function test_database_queue_and_claim_roll_back_together(): void
    {
        Queue::fake()->except([SendPushNotification::class]);
        $device = PushDevice::factory()->create(['marketing_enabled' => true]);
        $coupon = $this->coupon();
        try {
            DB::transaction(function () use ($device, $coupon): void {
                app(PushCampaignService::class)->coupon($device->user_id, $coupon->id);
                $this->assertDatabaseCount('jobs', 1);
                throw new RuntimeException('Rollback');
            });
        } catch (RuntimeException) {
        }
        $this->assertDatabaseCount('jobs', 0);
        $this->assertDatabaseCount('push_campaign_receipts', 0);
    }

    public function test_broadcast_continues_in_small_batches_without_duplicate_announcements(): void
    {
        $users = User::factory()->count(51)->create();
        foreach ($users as $user) {
            PushDevice::factory()->create(['user_id' => $user->id, 'marketing_enabled' => true]);
        }
        $coupon = $this->coupon();
        (new BroadcastCouponNotification($coupon->id))->handle(app(PushCampaignService::class));
        Queue::assertPushed(SendPushNotification::class, 50);
        Queue::assertPushed(BroadcastCouponNotification::class, fn ($job) => $job->afterUserId === $users[49]->id);
        (new BroadcastCouponNotification($coupon->id, $users[49]->id))->handle(app(PushCampaignService::class));
        Queue::assertPushed(SendPushNotification::class, 51);
        (new BroadcastCouponNotification($coupon->id))->handle(app(PushCampaignService::class));
        Queue::assertPushed(SendPushNotification::class, 51);
    }

    public function test_reminder_becomes_eligible_after_actual_free_quota_reset(): void
    {
        $user = User::factory()->create(['created_at' => now()->subDays(40),
            'free_ads_posted' => MarketplaceSetting::freeAdLimit(), 'free_quota_resets_at' => now()->subMinute()]);
        PushDevice::factory()->create(['user_id' => $user->id, 'marketing_enabled' => true]);
        $this->assertTrue(app(PushCampaignService::class)->remind($user->id));
        $this->assertSame(0, $user->fresh()->free_ads_posted);
        Queue::assertPushed(SendPushNotification::class, 1);
    }
}
