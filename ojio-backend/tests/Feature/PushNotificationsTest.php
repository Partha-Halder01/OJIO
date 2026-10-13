<?php

namespace Tests\Feature;

use App\Jobs\SendPushNotification;
use App\Models\Category;
use App\Models\Listing;
use App\Models\PremiumPackage;
use App\Models\PushDevice;
use App\Models\User;
use App\Services\FcmService;
use App\Services\PushNotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Tests\TestCase;

class PushNotificationsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.fcm.enabled' => true, 'services.fcm.queue_connection' => 'database']);
        Queue::fake();
        Http::preventStrayRequests();
    }

    private function payload(): array
    {
        return ['device_key' => str_repeat('a', 64), 'token' => str_repeat('t', 80), 'chat_enabled' => true];
    }

    private function listing(User $seller): Listing
    {
        return Listing::create([
            'user_id' => $seller->id, 'category_id' => Category::factory()->create()->id,
            'title' => 'Used phone', 'description' => 'Good condition', 'slug' => Str::uuid(),
            'price' => 1000, 'city' => 'Kolkata', 'status' => 'active',
        ]);
    }

    public function test_registration_is_authenticated_validated_encrypted_and_idempotent(): void
    {
        $this->postJson('/api/v1/user/push-device', $this->payload())->assertUnauthorized();
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $this->postJson('/api/v1/user/push-device', $this->payload())->assertOk()->assertExactJson(['status' => 'success']);
        $this->postJson('/api/v1/user/push-device', $this->payload())->assertOk();
        $this->assertDatabaseCount('push_devices', 1);
        $device = PushDevice::firstOrFail();
        $this->assertSame($this->payload()['token'], $device->token);
        $this->assertNotSame($device->token, DB::table('push_devices')->value('token'));
        $this->assertArrayNotHasKey('token', $device->toArray());
        $this->assertArrayNotHasKey('device_key_hash', $device->toArray());
        $this->postJson('/api/v1/user/push-device', [...$this->payload(), 'device_key' => 'bad'])->assertUnprocessable();
        $this->postJson('/api/v1/user/push-device', [...$this->payload(), 'token' => 'bad'])->assertUnprocessable();
        $user->update(['is_blocked' => true]);
        $this->postJson('/api/v1/user/push-device', $this->payload())->assertForbidden();
    }

    public function test_known_token_cannot_be_hijacked_but_same_installation_can_switch_accounts(): void
    {
        $first = User::factory()->create();
        $second = User::factory()->create();
        Sanctum::actingAs($first);
        $this->postJson('/api/v1/user/push-device', $this->payload())->assertOk();
        Sanctum::actingAs($second);
        $this->postJson('/api/v1/user/push-device', [...$this->payload(), 'device_key' => str_repeat('b', 64)])->assertConflict();
        $this->assertEquals($first->id, PushDevice::first()->user_id);
        $this->deleteJson('/api/v1/user/push-device', ['device_key' => $this->payload()['device_key']])->assertOk();
        $this->assertDatabaseCount('push_devices', 1);
        $this->postJson('/api/v1/user/push-device', $this->payload())->assertOk();
        $this->assertEquals($second->id, PushDevice::first()->user_id);
        $this->deleteJson('/api/v1/user/push-device', ['device_key' => $this->payload()['device_key']])->assertOk();
        $this->assertDatabaseCount('push_devices', 0);
    }

    public function test_chat_only_notifies_receiver_after_a_real_message_and_honours_preference(): void
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();
        $listing = $this->listing($seller);
        $device = PushDevice::factory()->create(['user_id' => $seller->id]);
        PushDevice::factory()->create(['user_id' => $seller->id, 'chat_enabled' => false]);
        PushDevice::factory()->create(['user_id' => $buyer->id]);
        Sanctum::actingAs($buyer);
        $thread = $this->postJson('/api/v1/chats/open', ['listing_id' => $listing->id])->assertOk()->json('data.thread_id');
        Queue::assertNothingPushed();
        $this->postJson('/api/v1/chats/send', ['thread_id' => $thread, 'message' => 'Private message'])->assertCreated();
        Queue::assertPushed(SendPushNotification::class, 1);
        Queue::assertPushed(SendPushNotification::class, fn ($job) => $job->deviceId === $device->id && $job->recipientId === $seller->id
            && $job->queue === 'push' && $job->data['thread_id'] === (string) $thread
            && $job->body !== 'Private message');
    }

    public function test_admin_changes_notify_only_owner_once_and_rollback_sends_nothing(): void
    {
        $seller = User::factory()->create();
        $listing = $this->listing($seller);
        PushDevice::factory()->create(['user_id' => $seller->id]);
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        $this->post('/admin/listings/'.$listing->id.'/status', ['status' => 'rejected'])->assertRedirect();
        $this->post('/admin/listings/'.$listing->id.'/status', ['status' => 'rejected'])->assertRedirect();
        Queue::assertPushed(SendPushNotification::class, 1);
        Queue::assertPushed(SendPushNotification::class, fn ($job) => $job->recipientId === $seller->id && $job->data['type'] === 'ad_status');
        Queue::fake();
        try {
            DB::transaction(function () use ($seller): void {
                app(PushNotificationService::class)->notify($seller->id, 'payment', 'Payment', 'Confirmed', ['event_id' => 'rollback']);
                throw new RuntimeException('Roll back');
            });
        } catch (RuntimeException) {
        }
        Queue::assertNothingPushed();
    }

    public function test_wallet_payment_notifies_once_only_after_actual_settlement(): void
    {
        $user = User::factory()->create(['wallet_balance_paise' => 10000]);
        PushDevice::factory()->create(['user_id' => $user->id]);
        $package = PremiumPackage::create([
            'key' => 'per_ad', 'name' => 'Single Ad', 'price' => 49,
            'ads_limit' => 1, 'duration_days' => 0, 'badge_enabled' => false, 'is_active' => true,
        ]);
        Sanctum::actingAs($user);
        $payload = ['package_id' => $package->id, 'request_id' => (string) Str::uuid()];
        $this->postJson('/api/v1/monetization/wallet', $payload)->assertOk();
        $this->postJson('/api/v1/monetization/wallet', $payload)->assertOk();
        Queue::assertPushed(SendPushNotification::class, 1);
        Queue::assertPushed(SendPushNotification::class, fn ($job) => $job->data['type'] === 'payment' && $job->recipientId === $user->id);
        $this->assertSame(5100, $user->fresh()->wallet_balance_paise);
        $user->wallet_balance_paise = 0;
        $user->save();
        $this->postJson('/api/v1/monetization/wallet', [...$payload, 'request_id' => (string) Str::uuid()])->assertUnprocessable();
        Queue::assertPushed(SendPushNotification::class, 1);
    }

    private function configureFcm(): string
    {
        $options = ['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA];
        $windowsConfig = dirname(PHP_BINARY).'/extras/ssl/openssl.cnf';
        if (is_file($windowsConfig)) {
            $options['config'] = $windowsConfig;
        }
        $key = openssl_pkey_new($options);
        openssl_pkey_export($key, $private, null, $options);
        config([
            'services.fcm.project_id' => 'test-project',
            'services.fcm.credentials_json' => json_encode([
                'type' => 'service_account', 'project_id' => 'test-project',
                'client_email' => 'push@test-project.iam.gserviceaccount.com',
                'private_key_id' => 'test-key', 'private_key' => $private,
            ]),
        ]);

        return openssl_pkey_get_details($key)['key'];
    }

    public function test_http_v1_oauth_signature_payload_and_access_token_cache(): void
    {
        $public = $this->configureFcm();
        $device = PushDevice::factory()->create();
        Http::fake([
            'oauth2.googleapis.com/token' => Http::response(['access_token' => 'server-access', 'expires_in' => 3600]),
            'fcm.googleapis.com/*' => Http::response(['name' => 'projects/test-project/messages/one']),
        ]);
        $data = ['type' => 'chat', 'recipient_user_id' => (string) $device->user_id, 'event_id' => 'chat_1', 'thread_id' => '1'];
        app(FcmService::class)->send($device, 'New message', 'Open OJIO', $data);
        app(FcmService::class)->send($device, 'New message', 'Open OJIO', $data);
        Http::assertSentCount(3);
        Http::assertSent(function ($request) use ($public): bool {
            if ($request->url() !== 'https://oauth2.googleapis.com/token') {
                return false;
            }
            [$header, $claims, $signature] = explode('.', $request['assertion']);
            $this->assertSame(1, openssl_verify($header.'.'.$claims, base64_decode(strtr($signature, '-_', '+/')), $public, OPENSSL_ALGO_SHA256));
            $this->assertSame('https://www.googleapis.com/auth/firebase.messaging', json_decode(base64_decode(strtr($claims, '-_', '+/')), true)['scope']);

            return true;
        });
        Http::assertSent(fn ($request) => str_contains($request->url(), '/projects/test-project/messages:send')
            && $request->hasHeader('Authorization', 'Bearer server-access')
            && $request['message']['token'] === $device->token && $request['message']['data'] === $data);
    }

    public function test_unregistered_device_is_removed_but_other_errors_are_retried_without_deletion(): void
    {
        $this->configureFcm();
        Cache::put('fcm_oauth_'.hash('sha256', 'test-projectpush@test-project.iam.gserviceaccount.comtest-key'), 'cached-token', 3600);
        $device = PushDevice::factory()->create();
        Http::fake(['fcm.googleapis.com/*' => Http::sequence()->push(['error' => ['details' => [[
            '@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError', 'errorCode' => 'UNREGISTERED',
        ]]]], 404)->push([], 503)]);
        app(FcmService::class)->send($device, 'Test', 'Test', ['event_id' => 'test']);
        $this->assertDatabaseMissing('push_devices', ['id' => $device->id]);
        $device = PushDevice::factory()->create();
        try {
            app(FcmService::class)->send($device, 'Test', 'Test', ['event_id' => 'test']);
            $this->fail('Transient delivery errors must reach the queue retry mechanism.');
        } catch (RuntimeException $exception) {
            $this->assertSame('FCM delivery failed (HTTP 503).', $exception->getMessage());
        }
        $this->assertDatabaseHas('push_devices', ['id' => $device->id]);
    }

    public function test_queued_job_cannot_follow_a_device_to_a_new_user_or_a_rotated_token(): void
    {
        $device = PushDevice::factory()->create();
        $job = new SendPushNotification($device->id, $device->user_id, $device->token_hash, 'Test', 'Test', ['type' => 'chat', 'event_id' => 'test']);
        $fcm = $this->mock(FcmService::class);
        $fcm->shouldNotReceive('send');
        $device->update(['user_id' => User::factory()->create()->id]);
        $job->handle($fcm);
        $device->update(['user_id' => $job->recipientId, 'token_hash' => hash('sha256', 'new')]);
        $job->handle($fcm);
        $device->update(['token_hash' => $job->tokenHash, 'chat_enabled' => false]);
        $job->handle($fcm);
    }

    public function test_project_mismatch_fails_closed_without_an_http_request(): void
    {
        $this->configureFcm();
        config(['services.fcm.project_id' => 'wrong-project']);
        $this->expectException(RuntimeException::class);
        app(FcmService::class)->send(PushDevice::factory()->create(), 'Test', 'Test', ['event_id' => 'test']);
    }

    public function test_test_command_targets_only_one_registered_account(): void
    {
        $user = User::factory()->create();
        PushDevice::factory()->create(['user_id' => $user->id]);
        PushDevice::factory()->create();
        $this->artisan('fcm:test', ['user' => $user->id])->assertSuccessful();
        Queue::assertPushed(SendPushNotification::class, 1);
        Queue::assertPushed(SendPushNotification::class, fn ($job) => $job->recipientId === $user->id && $job->data['type'] === 'test');
        $this->artisan('fcm:test', ['user' => -1])->assertFailed();
        config(['services.fcm.enabled' => false]);
        $this->artisan('fcm:test', ['user' => $user->id])->assertFailed();
        Queue::assertPushed(SendPushNotification::class, 1);
    }

    public function test_expired_sessions_and_blocked_recipients_do_not_receive_queued_pushes(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('phone', ['*'], now()->subMinute())->accessToken;
        $device = PushDevice::factory()->create(['user_id' => $user->id, 'personal_access_token_id' => $token->id]);
        $job = new SendPushNotification($device->id, $user->id, $device->token_hash, 'Test', 'Test', ['type' => 'test', 'event_id' => 'test']);
        $fcm = $this->mock(FcmService::class);
        $fcm->shouldNotReceive('send');
        $job->handle($fcm);
        $token->update(['expires_at' => now()->addDay()]);
        $user->update(['is_blocked' => true]);
        $job->handle($fcm);
        $token->delete();
        $this->assertDatabaseMissing('push_devices', ['id' => $device->id]);
    }
}
