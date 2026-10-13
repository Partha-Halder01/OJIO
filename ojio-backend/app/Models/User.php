<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
        'phone',
        'avatar',
        'city',
        'state',
        'country',
        'latitude',
        'longitude',
        'free_ads_posted',
        'free_quota_resets_at',
        'is_blocked',
        'role',
        'is_premium',
        'has_diamond_badge',
        'premium_until',
        'paid_ads_quota',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'paidPremiumOrders',
        'welcome_push_pending',
        'posting_reminder_queued_at',
    ];

    public function getFreeAdsLimitAttribute(): int
    {
        return MarketplaceSetting::freeAdLimit();
    }

    protected static function booted(): void
    {
        static::creating(function (User $user): void {
            $user->welcome_push_pending = true;
        });
    }

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_blocked' => 'boolean',
            'free_ads_posted' => 'integer',
            'free_quota_resets_at' => 'datetime',
            'is_premium' => 'boolean',
            'has_diamond_badge' => 'boolean',
            'paid_ads_quota' => 'integer',
            'premium_until' => 'datetime',
            'paid_quota_until' => 'datetime',
            'wallet_balance_paise' => 'integer',
            'welcome_push_pending' => 'boolean',
            'posting_reminder_queued_at' => 'datetime',
        ];
    }

    public function listings()
    {
        return $this->hasMany(Listing::class);
    }

    public function paidPremiumOrders(): HasMany
    {
        return $this->hasMany(PaymentOrder::class)
            ->select(['id', 'user_id', 'provider', 'benefits', 'expires_at'])
            ->where('purpose', 'premium')->where('status', 'paid');
    }

    /** @return array{is_premium: bool, has_diamond_badge: bool, premium_until: ?string, diamond_badge_until: ?string} */
    public function premiumStatus(): array
    {
        $this->loadMissing('paidPremiumOrders');
        $active = $this->paidPremiumOrders->filter(fn (PaymentOrder $order) => ! $order->expires_at || $order->expires_at->isFuture());
        $diamond = $active->filter(fn (PaymentOrder $order) => (bool) ($order->benefits['badge_enabled'] ?? false)
            || ($order->provider === 'legacy' && (bool) $this->getRawOriginal('has_diamond_badge')));
        $expiry = static function (Collection $orders): ?string {
            if ($orders->isEmpty() || $orders->contains(fn (PaymentOrder $order) => $order->expires_at === null)) {
                return null;
            }

            return $orders->sortByDesc(fn (PaymentOrder $order) => $order->expires_at->getTimestamp())->first()->expires_at->toISOString();
        };

        return [
            'is_premium' => $active->isNotEmpty(),
            'has_diamond_badge' => $diamond->isNotEmpty(),
            'premium_until' => $expiry($active),
            'diamond_badge_until' => $expiry($diamond),
        ];
    }

    public function toArray(): array
    {
        $status = $this->premiumStatus();

        return array_merge(parent::toArray(), $status);
    }

    public function canPostFreeAd(): bool
    {
        $this->refreshFreeQuota();
        if (PaymentOrder::where('user_id', $this->id)->where('purpose', 'premium')->where('status', 'paid')->exists()) {
            return $this->free_ads_posted < MarketplaceSetting::freeAdLimit() || PaymentOrder::where('user_id', $this->id)
                ->where('purpose', 'premium')->where('status', 'paid')->where('remaining_ads', '>', 0)
                ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))->exists();
        }
        if ($this->paid_ads_quota > 0 && (! $this->paid_quota_until || $this->paid_quota_until->isFuture())) {
            return true;
        }

        return $this->free_ads_posted < MarketplaceSetting::freeAdLimit();
    }

    public function refreshFreeQuota(): void
    {
        DB::transaction(function () {
            $user = static::lockForUpdate()->findOrFail($this->id);
            $limit = MarketplaceSetting::freeAdLimit();
            if ($limit > 0 && $user->free_ads_posted >= $limit && ! $user->free_quota_resets_at) {
                $lastFreeAdAt = $user->listings()->withTrashed()->where('is_paid_ad', false)
                    ->latest('created_at')->value('created_at');
                $user->free_quota_resets_at = ($lastFreeAdAt ? Carbon::parse($lastFreeAdAt) : now())->addDays(30);
            }
            if ($user->free_quota_resets_at && $user->free_quota_resets_at->lte(now())) {
                $user->free_ads_posted = 0;
                $user->free_quota_resets_at = null;
            }
            if ($user->isDirty()) {
                $user->save();
            }
            $this->setRawAttributes($user->getAttributes(), true);
        });
    }
}
