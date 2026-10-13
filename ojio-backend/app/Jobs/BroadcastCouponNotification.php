<?php

namespace App\Jobs;

use App\Models\Coupon;
use App\Models\PushDevice;
use App\Models\User;
use App\Services\PushCampaignService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class BroadcastCouponNotification implements ShouldQueue
{
    use Queueable;

    /**
     * Create a new job instance.
     */
    public int $tries = 3;

    public function __construct(public int $couponId, public int $afterUserId = 0) {}

    /**
     * Execute the job.
     */
    public function handle(PushCampaignService $campaigns): void
    {
        if (! config('services.fcm.enabled') || ! Coupon::valid()->forApp()->whereKey($this->couponId)->exists()) {
            return;
        }
        $users = User::where('is_blocked', false)->where('id', '>', $this->afterUserId)
            ->whereIn('id', PushDevice::select('user_id')->where('marketing_enabled', true))
            ->orderBy('id')->limit(50)->get();
        foreach ($users as $user) {
            $campaigns->coupon((int) $user->id, $this->couponId);
        }
        if ($users->count() === 50) {
            self::dispatch($this->couponId, (int) $users->last()->id)
                ->onConnection(config('services.fcm.queue_connection'))->onQueue('push');
        }
    }
}
