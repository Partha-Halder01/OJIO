<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('premium_packages')) {
            Schema::create('premium_packages', function (Blueprint $table) {
                $table->id();
                $table->string('key')->unique();
                $table->string('name');
                $table->decimal('price', 10, 2);
                $table->integer('ads_limit')->default(1);
                $table->integer('duration_days')->default(30);
                $table->text('description')->nullable();
                $table->boolean('badge_enabled')->default(false);
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'is_premium')) {
                $table->boolean('is_premium')->default(false)->after('role');
            }
            if (!Schema::hasColumn('users', 'has_diamond_badge')) {
                $table->boolean('has_diamond_badge')->default(false)->after('is_premium');
            }
            if (!Schema::hasColumn('users', 'premium_until')) {
                $table->timestamp('premium_until')->nullable()->after('has_diamond_badge');
            }
            if (!Schema::hasColumn('users', 'paid_ads_quota')) {
                $table->integer('paid_ads_quota')->default(0)->after('premium_until');
            }
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('premium_packages');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['is_premium', 'has_diamond_badge', 'premium_until', 'paid_ads_quota']);
        });
    }
};
