<?php

namespace App\Models;

use Database\Factories\PushDeviceFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PushDevice extends Model
{
    /** @use HasFactory<PushDeviceFactory> */
    use HasFactory;

    protected $guarded = [];

    protected $hidden = ['token', 'token_hash', 'device_key_hash'];

    protected function casts(): array
    {
        return ['token' => 'encrypted', 'chat_enabled' => 'boolean', 'marketing_enabled' => 'boolean', 'last_seen_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
