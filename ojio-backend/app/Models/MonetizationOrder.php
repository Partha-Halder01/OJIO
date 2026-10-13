<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MonetizationOrder extends Model
{
    protected $fillable = [
        'user_id',
        'listing_id',
        'amount',
        'currency',
        'payment_provider',
        'transaction_id',
        'payment_status',
        'ad_type',
        'coupon_code',
        'discount_amount',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function listing()
    {
        return $this->belongsTo(Listing::class);
    }
}
