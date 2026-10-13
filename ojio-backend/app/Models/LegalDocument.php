<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LegalDocument extends Model
{
    protected $fillable = ['slug', 'title', 'content', 'is_draft', 'edited_by'];

    protected function casts(): array
    {
        return ['is_draft' => 'boolean'];
    }

    public static function forSlug(string $slug): self
    {
        abort_unless(in_array($slug, ['terms', 'privacy'], true), 404);

        return static::where('slug', $slug)->first() ?? new static(config('legal_documents.'.$slug));
    }
}
