<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Banner extends Model
{
    protected $fillable = [
        'title',
        'image_url',
        'target_url',
        'placement',
        'sort_order',
        'is_active',
        'starts_at',
        'ends_at',
        'clicks_count',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'starts_at' => 'datetime',
        'ends_at' => 'datetime',
        'clicks_count' => 'integer',
    ];

    public function getImageUrlAttribute($value)
    {
        if (empty($value) || str_contains($value, '1556742049-0a67c5574f73')) {
            return 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&auto=format&fit=crop&q=80';
        }
        if (!str_starts_with($value, 'http://') && !str_starts_with($value, 'https://')) {
            return asset('storage/' . ltrim($value, '/'));
        }
        return $value;
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true)
            ->where(function ($q) {
                $q->whereNull('starts_at')->orWhere('starts_at', '<=', now());
            })
            ->where(function ($q) {
                $q->whereNull('ends_at')->orWhere('ends_at', '>=', now());
            })
            ->orderBy('sort_order');
    }
}
