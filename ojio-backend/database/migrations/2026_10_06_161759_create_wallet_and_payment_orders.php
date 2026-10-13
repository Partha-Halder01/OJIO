<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->unsignedBigInteger('wallet_balance_paise')->default(0);
            $table->timestamp('paid_quota_until')->nullable();
        });
        Schema::create('payment_orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('package_id')->nullable()->constrained('premium_packages');
            $table->string('purpose');
            $table->string('provider')->default('razorpay');
            $table->string('provider_order_id')->nullable()->unique();
            $table->string('provider_payment_id')->nullable()->unique();
            $table->uuid('request_id')->nullable();
            $table->unsignedBigInteger('amount_paise');
            $table->unsignedBigInteger('discount_paise')->default(0);
            $table->string('coupon_code')->nullable();
            $table->json('benefits')->nullable();
            $table->unsignedInteger('remaining_ads')->default(0);
            $table->timestamp('expires_at')->nullable();
            $table->string('status')->default('pending');
            $table->timestamps();
            $table->unique(['user_id', 'request_id']);
        });
        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('payment_order_id')->unique()->constrained();
            $table->bigInteger('amount_paise');
            $table->unsignedBigInteger('balance_paise');
            $table->string('description');
            $table->timestamps();
        });
        Schema::table('listings', function (Blueprint $table) {
            $table->uuid('post_request_id')->nullable();
            $table->unique(['user_id', 'post_request_id']);
        });
        DB::table('users')->where('paid_ads_quota', '>', 0)->orderBy('id')->chunkById(100, function ($users) {
            foreach ($users as $user) {
                DB::table('payment_orders')->insert([
                    'user_id' => $user->id, 'purpose' => 'premium', 'provider' => 'legacy', 'amount_paise' => 0,
                    'status' => 'paid', 'remaining_ads' => $user->paid_ads_quota,
                    'expires_at' => in_array($user->badge_type ?? '', ['silver', 'diamond'], true) ? $user->premium_until : null,
                    'created_at' => now(), 'updated_at' => now(),
                ]);
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('wallet_transactions');
        Schema::table('listings', function (Blueprint $table) {
            $table->dropUnique(['user_id', 'post_request_id']);
            $table->dropColumn('post_request_id');
        });
        Schema::dropIfExists('payment_orders');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['wallet_balance_paise', 'paid_quota_until']);
        });
    }
};
