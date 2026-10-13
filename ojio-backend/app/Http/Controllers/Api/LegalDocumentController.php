<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\LegalDocument;
use Illuminate\Http\JsonResponse;

class LegalDocumentController extends Controller
{
    public function show(string $slug): JsonResponse
    {
        $document = LegalDocument::forSlug($slug);

        return response()->json(['status' => 'success', 'data' => [
            'slug' => $document->slug, 'title' => $document->title,
            'content' => $document->content, 'is_draft' => $document->is_draft,
            'updated_at' => $document->updated_at?->toIso8601String(),
        ]]);
    }
}
