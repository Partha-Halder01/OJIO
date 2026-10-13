<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\PremiumPackage;

class PremiumPackagesSeeder extends Seeder
{
    public function run(): void
    {
        $packages = [
            [
                'key' => 'per_ad',
                'name' => 'Per Ad',
                'price' => 49.00,
                'ads_limit' => 1,
                'duration_days' => 30,
                'description' => 'Per Ad- 49/- (After monthly free limit reached)',
                'badge_enabled' => false,
                'is_active' => true,
            ],
            [
                'key' => 'monthly_5',
                'name' => 'Monthly 5 Ads',
                'price' => 199.00,
                'ads_limit' => 5,
                'duration_days' => 30,
                'description' => 'Monthly 5Ads- 199/-',
                'badge_enabled' => false,
                'is_active' => true,
            ],
            [
                'key' => 'monthly_unlimited',
                'name' => 'Monthly Unlimited',
                'price' => 599.00,
                'ads_limit' => 999999,
                'duration_days' => 30,
                'description' => 'Monthly Unlimited- 599/- (Includes 💎 Verified Diamond Member Badge)',
                'badge_enabled' => true,
                'is_active' => true,
            ],
        ];

        foreach ($packages as $pkg) {
            PremiumPackage::updateOrCreate(
                ['key' => $pkg['key']],
                $pkg
            );
        }
    }
}
