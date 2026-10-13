<?php

namespace App\Services;

use App\Jobs\SendPushNotification;
use App\Models\PushDevice;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class PushNotificationService
{
    /** @param array<string, string> $data */
    public function notify(int $userId, string $type, string $title, string $body, array $data): void
    {
        if (! config('services.fcm.enabled')) {
            return;
        }
        DB::afterCommit(function () use ($userId, $type, $title, $body, $data): void {
            try {
                PushDevice::where('user_id', $userId)->when($type === 'chat', fn ($query) => $query->where('chat_enabled', true))
                    ->eachById(function (PushDevice $device) use ($userId, $type, $title, $body, $data): void {
                        $job = new SendPushNotification($device->id, $userId, $device->token_hash, $title, $body, [
                            ...$data, 'type' => $type, 'recipient_user_id' => (string) $userId,
                        ]);
                        Bus::dispatch($job->onConnection(config('services.fcm.queue_connection'))->onQueue('push'));
                    });
            } catch (Throwable) {
                Log::warning('Push notification could not be queued. Check the push queue configuration.');
            }
        });
    }
}
