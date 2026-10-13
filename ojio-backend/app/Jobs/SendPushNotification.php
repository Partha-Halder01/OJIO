<?php

namespace App\Jobs;

use App\Models\Coupon;
use App\Models\MarketplaceSetting;
use App\Models\PushDevice;
use App\Services\FcmService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Laravel\Sanctum\PersonalAccessToken;

class SendPushNotification implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public int $timeout = 40;

    /** @param array<string, string> $data */
    public function __construct(
        public int $deviceId,
        public int $recipientId,
        public string $tokenHash,
        public string $title,
        public string $body,
        public array $data,
    ) {}

    /** @return array<int, int> */
    public function backoff(): array
    {
        return [10, 60, 300];
    }

    public function handle(FcmService $fcm): void
    {
        if (! config('services.fcm.enabled')) {
            return;
        }
        $device = PushDevice::whereKey($this->deviceId)->where('user_id', $this->recipientId)
            ->where('token_hash', $this->tokenHash)->whereHas('user', fn ($query) => $query->where('is_blocked', false))->first();
        if (! $device || ($this->data['type'] === 'chat' && ! $device->chat_enabled)) {
            return;
        }
        $type = $this->data['type'];
        if (in_array($type, ['coupon', 'post_reminder'], true) && ! $device->marketing_enabled) {
            return;
        }
        if ($type === 'coupon' && ! Coupon::valid()->forApp()->whereKey((int) ($this->data['coupon_id'] ?? 0))->exists()) {
            return;
        }
        if ($type === 'post_reminder') {
            $user = $device->user;
            $user->refreshFreeQuota();
            if ($user->free_ads_posted >= MarketplaceSetting::freeAdLimit()) {
                return;
            }
        }
        if ($device->personal_access_token_id !== null) {
            $session = PersonalAccessToken::find($device->personal_access_token_id);
            $expiration = config('sanctum.expiration');
            if (! $session || (int) $session->tokenable_id !== $this->recipientId
                || ($session->expires_at && $session->expires_at->isPast())
                || ($expiration && $session->created_at->lte(now()->subMinutes($expiration)))) {
                return;
            }
        }
        $fcm->send($device, $this->title, $this->body, $this->data);
    }
}
