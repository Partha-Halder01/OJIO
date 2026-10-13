<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PaymentOrder extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return ['benefits' => 'array', 'amount_paise' => 'integer', 'discount_paise' => 'integer', 'remaining_ads' => 'integer', 'expires_at' => 'datetime'];
    }
}
