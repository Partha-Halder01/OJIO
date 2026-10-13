<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Listing extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'user_id',
        'post_request_id',
        'category_id',
        'title',
        'slug',
        'description',
        'price',
        'is_negotiable',
        'city',
        'state',
        'locality',
        'latitude',
        'longitude',
        'phone_number',
        'hide_phone',
        'attributes',
        'status',
        'rejection_reason',
        'is_featured',
        'is_paid_ad',
        'views_count',
    ];

    protected $casts = [
        'price' => 'decimal:2',
        'is_negotiable' => 'boolean',
        'hide_phone' => 'boolean',
        'is_featured' => 'boolean',
        'is_paid_ad' => 'boolean',
        'attributes' => 'array',
        'views_count' => 'integer',
        'admin_update_version' => 'integer',
        'admin_seen_version' => 'integer',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function toArray(): array
    {
        $data = parent::toArray();
        if ($this->hide_phone) {
            $data['phone_number'] = null;
        }
        if (isset($data['user'])) {
            unset($data['user']['phone'], $data['user']['email'], $data['user']['wallet_balance_paise']);
        }

        return $data;
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function images()
    {
        return $this->hasMany(ListingImage::class)->orderBy('sort_order');
    }

    public function primaryImage()
    {
        return $this->hasOne(ListingImage::class)->ofMany([
            'is_primary' => 'max',
            'id' => 'min',
        ]);
    }
}
