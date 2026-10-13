<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;

class CategoryController extends Controller
{
    public function index()
    {
        $available = Category::available()->orderBy('sort_order')->orderBy('name')->get();
        $categories = $available->whereNull('parent_id')->values();
        foreach ($categories as $category) {
            // Preserve legacy nested IDs while presenting one subcategory picker.
            $ids = Category::descendantIds($category->id, $available);
            $category->setRelation('subcategories', $available->whereIn('id', $ids)->where('id', '!=', $category->id)->values());
        }

        return response()->json([
            'status' => 'success',
            'data' => $categories,
        ]);
    }

    public function show($id)
    {
        $category = Category::available()->findOrFail($id);
        $category->setRelation('subcategories', Category::available()->whereIn('id', Category::descendantIds((int) $id))->where('id', '!=', $id)->orderBy('sort_order')->get());

        return response()->json([
            'status' => 'success',
            'data' => $category,
        ]);
    }
}
