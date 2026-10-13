<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('coupons', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();
            $table->string('description')->nullable();
            $table->enum('type', ['percentage', 'fixed'])->default('percentage');
            $table->decimal('value', 8, 2); // e.g. 100 for 100% or 49 for ₹49 off
            $table->boolean('is_active')->default(true);
            $table->boolean('show_on_landing')->default(true);
            $table->boolean('show_in_app')->default(true);
            $table->dateTime('expires_at')->nullable();
            $table->integer('usage_limit')->nullable();
            $table->integer('times_used')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('coupons');
    }
};
