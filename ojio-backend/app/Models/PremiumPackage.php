<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PremiumPackage extends Model
{
    protected $fillable = [
        'key',
        'name',
        'price',
        'ads_limit',
        'duration_days',
        'description',
        'badge_enabled',
        'is_active',
    ];

    protected $casts = [
        'price' => 'decimal:2',
        'ads_limit' => 'integer',
        'duration_days' => 'integer',
        'badge_enabled' => 'boolean',
        'is_active' => 'boolean',
    ];
}
