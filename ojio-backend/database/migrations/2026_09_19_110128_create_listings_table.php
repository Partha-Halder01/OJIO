<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('listings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('category_id')->constrained()->cascadeOnDelete();
            $table->string('title');
            $table->string('slug')->unique();
            $table->text('description');
            $table->decimal('price', 12, 2);
            $table->boolean('is_negotiable')->default(false);
            $table->string('city');
            $table->string('state')->nullable();
            $table->string('locality')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('phone_number')->nullable();
            $table->boolean('hide_phone')->default(false);
            
            // Dynamic attributes (brand, model, year, fuel_type, km_driven, storage, etc.)
            $table->json('attributes')->nullable();
            
            // Status: pending, active, rejected, sold
            $table->string('status')->default('active');
            $table->text('rejection_reason')->nullable();
            
            // Featured / Promoted
            $table->boolean('is_featured')->default(false);
            $table->boolean('is_paid_ad')->default(false);
            $table->integer('views_count')->default(0);

            $table->timestamps();
            $table->softDeletes();
            
            $table->index(['latitude', 'longitude']);
            $table->index('status');
            $table->index('price');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('listings');
    }
};
