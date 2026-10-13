<?php

namespace App\Services;

use App\Jobs\SendPushNotification;
use App\Models\Coupon;
use App\Models\MarketplaceSetting;
use App\Models\PushDevice;
use App\Models\User;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\DB;

class PushCampaignService
{
    public function welcome(int $userId): void
    {
        if (! config('services.fcm.enabled')) {
            return;
        }
        DB::transaction(function () use ($userId): void {
            $user = User::whereKey($userId)->where('is_blocked', false)->lockForUpdate()->first();
            if (! $user || ! $user->welcome_push_pending) {
                return;
            }
            if ($this->queue($user, 'welcome', 'Welcome to OJIO!', 'Discover nearby deals or give your unused items a new home.', 'welcome_'.$userId)) {
                $user->welcome_push_pending = false;
                $user->save();
            }
        });
    }

    public function coupon(int $userId, int $couponId): void
    {
        if (! config('services.fcm.enabled')) {
            return;
        }
        DB::transaction(function () use ($userId, $couponId): void {
            $user = User::whereKey($userId)->where('is_blocked', false)->lockForUpdate()->first();
            $coupon = Coupon::valid()->forApp()->find($couponId);
            $event = 'coupon_'.$couponId;
            if (! $user || ! $coupon || DB::table('push_campaign_receipts')->where('user_id', $userId)->where('event_key', $event)->exists()) {
                return;
            }
            if ($this->queue($user, 'coupon', 'New OJIO offer', 'Use '.$coupon->code.' on eligible premium packages. Check the offer details before paying.', $event, ['coupon_id' => (string) $couponId])) {
                DB::table('push_campaign_receipts')->insert(['user_id' => $userId, 'event_key' => $event, 'created_at' => now()]);
            }
        });
    }

    public function remind(int $userId): bool
    {
        if (! config('services.fcm.enabled')) {
            return false;
        }

        return DB::transaction(function () use ($userId): bool {
            $user = User::whereKey($userId)->where('is_blocked', false)->lockForUpdate()->first();
            if (! $user || $user->created_at->gt(now()->subDays(7)) ||
                ($user->posting_reminder_queued_at && $user->posting_reminder_queued_at->gt(now()->subDays(7)))) {
                return false;
            }
            $user->refreshFreeQuota();
            if ($user->free_ads_posted >= MarketplaceSetting::freeAdLimit()) {
                return false;
            }
            $event = 'posting_'.$userId.'_'.now()->timestamp;
            if (! $this->queue($user, 'post_reminder', 'Have something you no longer use?', 'Your free posting quota is available. Create an ad and connect with nearby buyers.', $event)) {
                return false;
            }
            $user->posting_reminder_queued_at = now();
            $user->save();

            return true;
        });
    }

    /** @param array<string, string> $data */
    private function queue(User $user, string $type, string $title, string $body, string $event, array $data = []): bool
    {
        $devices = PushDevice::where('user_id', $user->id)
            ->when($type !== 'welcome', fn ($query) => $query->where('marketing_enabled', true))->get();
        foreach ($devices as $device) {
            $job = new SendPushNotification($device->id, $user->id, $device->token_hash, $title, $body, [
                ...$data, 'type' => $type, 'event_id' => $event, 'recipient_user_id' => (string) $user->id,
            ]);
            // On the database queue, claim and jobs commit atomically.
            Bus::dispatch($job->onConnection(config('services.fcm.queue_connection'))->onQueue('push')->beforeCommit());
        }

        return $devices->isNotEmpty();
    }
}
