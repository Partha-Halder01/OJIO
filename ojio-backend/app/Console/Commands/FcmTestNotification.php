<?php

namespace App\Console\Commands;

use App\Models\PushDevice;
use App\Models\User;
use App\Services\PushNotificationService;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Str;

#[Signature('fcm:test {user : ID of your test account}')]
#[Description('Queue a private FCM test notification for one registered user')]
class FcmTestNotification extends Command
{
    public function handle(PushNotificationService $push): int
    {
        if (! config('services.fcm.enabled')) {
            $this->error('FCM is disabled. Configure server credentials and enable FCM first.');

            return self::FAILURE;
        }
        $id = filter_var($this->argument('user'), FILTER_VALIDATE_INT);
        $user = $id && $id > 0 ? User::find($id) : null;
        if (! $user || $user->is_blocked) {
            $this->error('The test account does not exist or is blocked.');

            return self::FAILURE;
        }
        if (! PushDevice::where('user_id', $user->id)->exists()) {
            $this->error('No device registered. Install the updated app, log in and allow notifications.');

            return self::FAILURE;
        }
        $push->notify($user->id, 'test', 'OJIO test notification', 'Firebase notifications are connected.', ['event_id' => 'test_'.Str::uuid()]);
        $this->info('Test notification queued. Keep the push queue worker running and check the phone.');

        return self::SUCCESS;
    }
}
