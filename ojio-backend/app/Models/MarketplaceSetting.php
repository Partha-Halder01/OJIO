<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MarketplaceSetting extends Model
{
    protected $primaryKey = 'key';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = ['key', 'value'];

    public static function freeAdLimit(): int
    {
        return (int) (static::whereKey('free_ads_limit')->value('value') ?? 2);
    }
}
