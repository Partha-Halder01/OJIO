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
        Schema::table('push_devices', function (Blueprint $table): void {
            $table->boolean('marketing_enabled')->default(false);
        });
        Schema::table('users', function (Blueprint $table): void {
            $table->boolean('welcome_push_pending')->default(false);
            $table->timestamp('posting_reminder_queued_at')->nullable();
        });
        Schema::create('push_campaign_receipts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('event_key', 100);
            $table->timestamp('created_at');
            $table->unique(['user_id', 'event_key']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('push_campaign_receipts');
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn(['welcome_push_pending', 'posting_reminder_queued_at']);
        });
        Schema::table('push_devices', function (Blueprint $table): void {
            $table->dropColumn('marketing_enabled');
        });
    }
};
