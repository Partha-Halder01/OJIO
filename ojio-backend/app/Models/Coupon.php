<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Coupon extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'description',
        'type',
        'value',
        'is_active',
        'show_on_landing',
        'show_in_app',
        'expires_at',
        'usage_limit',
        'times_used',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'show_on_landing' => 'boolean',
        'show_in_app' => 'boolean',
        'expires_at' => 'datetime',
        'value' => 'float',
    ];

    public function scopeValid(Builder $query): Builder
    {
        return $query->where('is_active', true)
            ->where(function ($q) {
                $q->whereNull('expires_at')
                    ->orWhere('expires_at', '>', now());
            })
            ->where(function ($q) {
                $q->whereNull('usage_limit')
                    ->orWhere('usage_limit', 0)
                    ->orWhereRaw('times_used < usage_limit');
            });
    }

    public function scopeForLanding(Builder $query): Builder
    {
        return $query->where('show_on_landing', true);
    }

    public function scopeForApp(Builder $query): Builder
    {
        return $query->where('show_in_app', true);
    }

    public function isValid(): bool
    {
        if (! $this->is_active) {
            return false;
        }
        if ($this->expires_at && $this->expires_at->isPast()) {
            return false;
        }
        if ($this->usage_limit && $this->times_used >= $this->usage_limit) {
            return false;
        }

        return true;
    }
}
