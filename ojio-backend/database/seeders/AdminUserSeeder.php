<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        if (User::where('role', 'admin')->exists()) {
            $this->command?->info('An admin already exists; credentials were not changed.');

            return;
        }

        $details = Validator::make(config('services.admin_bootstrap'), [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'regex:/^\+91[6-9]\d{9}$/', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:12'],
            'city' => ['nullable', 'string', 'max:255'],
        ])->validate();

        $details['password'] = Hash::make($details['password']);
        $details['role'] = 'admin';
        User::create($details);
        $this->command?->info('Admin created using the configured private credentials.');
    }
}
