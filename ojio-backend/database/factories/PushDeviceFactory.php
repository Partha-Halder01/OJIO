<?php

namespace Database\Factories;

use App\Models\PushDevice;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<PushDevice> */
class PushDeviceFactory extends Factory
{
    public function definition(): array
    {
        $token = Str::random(80);

        return [
            'user_id' => User::factory(), 'device_key_hash' => hash('sha256', Str::random(64)),
            'token' => $token, 'token_hash' => hash('sha256', $token),
            'chat_enabled' => true, 'last_seen_at' => now(),
        ];
    }
}
