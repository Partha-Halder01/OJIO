<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ListingImage extends Model
{
    protected $fillable = [
        'listing_id',
        'image_path',
        'is_primary',
        'sort_order',
    ];

    protected $casts = [
        'is_primary' => 'boolean',
    ];

    public function listing()
    {
        return $this->belongsTo(Listing::class);
    }

    public function getImagePathAttribute(?string $value): string
    {
        if ($this->exists && str_starts_with($value ?? '', 'data:image/')) {
            return route('listing-images.show', ['id' => $this->id]);
        }

        if (empty($value)) {
            return 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=800&auto=format&fit=crop&q=80';
        }

        // If local:// scheme was saved
        if (str_starts_with($value, 'local://')) {
            return 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=800&auto=format&fit=crop&q=80';
        }

        // If relative storage path (e.g. listings/abc.jpg)
        if (! str_starts_with($value, 'http://') && ! str_starts_with($value, 'https://') && ! str_starts_with($value, 'data:')) {
            return asset('storage/'.ltrim($value, '/'));
        }

        return $value;
    }
}
