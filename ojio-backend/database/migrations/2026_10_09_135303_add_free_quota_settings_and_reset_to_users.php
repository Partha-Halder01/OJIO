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
        Schema::create('marketplace_settings', function (Blueprint $table) {
            $table->string('key')->primary();
            $table->unsignedInteger('value');
            $table->timestamps();
        });
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('free_quota_resets_at')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('free_quota_resets_at');
        });
        Schema::dropIfExists('marketplace_settings');
    }
};
