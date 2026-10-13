<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('phone')->nullable()->unique()->after('email');
            $table->string('avatar')->nullable()->after('phone');
            $table->string('city')->nullable()->after('avatar');
            $table->decimal('latitude', 10, 7)->nullable()->after('city');
            $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            $table->integer('free_ads_posted')->default(0)->after('longitude');
            $table->boolean('is_blocked')->default(false)->after('free_ads_posted');
            $table->string('role')->default('user')->after('is_blocked'); // admin, user
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['phone', 'avatar', 'city', 'latitude', 'longitude', 'free_ads_posted', 'is_blocked', 'role']);
        });
    }
};
