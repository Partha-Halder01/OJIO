<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('monetization_orders', function (Blueprint $table) {
            $table->string('coupon_code')->nullable()->after('ad_type');
            $table->decimal('discount_amount', 8, 2)->nullable()->after('coupon_code');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('monetization_orders', function (Blueprint $table) {
            $table->dropColumn(['coupon_code', 'discount_amount']);
        });
    }
};
