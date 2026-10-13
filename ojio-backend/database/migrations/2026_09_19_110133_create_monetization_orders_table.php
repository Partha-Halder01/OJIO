<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('monetization_orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('listing_id')->nullable()->constrained()->nullOnDelete();
            $table->decimal('amount', 8, 2);
            $table->string('currency')->default('INR');
            $table->string('payment_provider')->default('mock'); // razorpay, phonepe, stripe, mock
            $table->string('transaction_id')->nullable();
            $table->string('payment_status')->default('pending'); // pending, paid, failed
            $table->string('ad_type')->default('per_ad_fee'); // per_ad_fee (3rd ad+), featured_boost
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('monetization_orders');
    }
};
