<?php

namespace App\Console\Commands;

use App\Models\PushDevice;
use App\Models\User;
use App\Services\PushCampaignService;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

#[Signature('fcm:posting-reminders')]
#[Description('Queue opted-in posting reminders at most once every seven days')]
class SendPostingReminders extends Command
{
    /**
     * Execute the console command.
     */
    public function handle(PushCampaignService $campaigns): int
    {
        if (! config('services.fcm.enabled')) {
            $this->warn('FCM is disabled. No reminders queued.');

            return self::SUCCESS;
        }
        $count = 0;
        User::where('is_blocked', false)->where('created_at', '<=', now()->subDays(7))
            ->where(fn ($query) => $query->whereNull('posting_reminder_queued_at')->orWhere('posting_reminder_queued_at', '<=', now()->subDays(7)))
            ->whereIn('id', PushDevice::select('user_id')->where('marketing_enabled', true))
            ->chunkById(100, function ($users) use ($campaigns, &$count): void {
                foreach ($users as $user) {
                    $count += (int) $campaigns->remind((int) $user->id);
                }
            });
        $this->info('Posting reminders queued for '.$count.' users.');

        return self::SUCCESS;
    }
}
