<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Collection;

class Category extends Model
{
    use HasFactory;

    public static function availableIds(): array
    {
        $categories = static::all(['id', 'parent_id', 'is_active'])->keyBy('id');

        return $categories->filter(function ($category) use ($categories) {
            $seen = [];
            while ($category) {
                if (! $category->is_active || isset($seen[$category->id])) {
                    return false;
                }
                $seen[$category->id] = true;
                if (! $category->parent_id) {
                    return true;
                }
                $category = $categories->get($category->parent_id);
            }

            return false;
        })->keys()->all();
    }

    public function scopeAvailable(Builder $query): Builder
    {
        return $query->whereIn('id', static::availableIds());
    }

    public static function descendantIds(int $id, ?Collection $categories = null): array
    {
        $children = ($categories ?? static::all(['id', 'parent_id']))->groupBy('parent_id');
        $ids = [$id];
        for ($index = 0; $index < count($ids); $index++) {
            foreach ($children->get($ids[$index], collect()) as $child) {
                if (! in_array($child->id, $ids, true)) {
                    $ids[] = $child->id;
                }
            }
        }

        return $ids;
    }

    protected $fillable = [
        'parent_id',
        'name',
        'slug',
        'icon',
        'description',
        'custom_attributes_schema',
        'sort_order',
        'is_active',
    ];

    protected $casts = [
        'custom_attributes_schema' => 'array',
        'is_active' => 'boolean',
    ];

    public function parent()
    {
        return $this->belongsTo(Category::class, 'parent_id');
    }

    public function subcategories()
    {
        return $this->hasMany(Category::class, 'parent_id')->orderBy('sort_order');
    }

    public function listings()
    {
        return $this->hasMany(Listing::class);
    }
}
