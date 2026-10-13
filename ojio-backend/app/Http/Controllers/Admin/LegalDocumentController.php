<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\LegalDocument;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class LegalDocumentController extends Controller
{
    public function index(): View
    {
        return view('admin.legal', ['documents' => collect(['terms', 'privacy'])->map(fn (string $slug): LegalDocument => LegalDocument::forSlug($slug))]);
    }

    public function update(Request $request, string $slug): RedirectResponse
    {
        abort_unless(in_array($slug, ['terms', 'privacy'], true), 404);
        $request->merge(['title' => trim((string) $request->input('title')), 'content' => trim((string) $request->input('content'))]);
        $data = $request->validate([
            'title' => 'required|string|max:100',
            'content' => 'required|string|min:50|max:30000',
            'is_draft' => 'required|boolean',
        ]);
        LegalDocument::updateOrCreate(['slug' => $slug], [...$data, 'edited_by' => $request->user()->id]);

        return redirect()->route('admin.legal')->with('success', 'Legal document saved.');
    }
}
