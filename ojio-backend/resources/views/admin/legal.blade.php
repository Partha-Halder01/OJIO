@extends('admin.layout')
@section('title', 'Legal Pages')
@section('content')
<div class="max-w-4xl mx-auto space-y-6">
    <div class="flex items-center justify-between gap-4">
        <h1 class="text-xl font-bold">Legal Pages</h1>
        <nav class="flex gap-4 text-sm text-[#087CFE]">
            <a href="#terms">Terms</a><a href="#privacy">Privacy</a>
        </nav>
    </div>
    @foreach($documents as $document)
    <section id="{{ $document->slug }}" class="bg-white border border-slate-200 rounded-xl p-5 scroll-mt-20">
        <form method="POST" action="{{ route('admin.legal.update', $document->slug) }}" class="space-y-4">
            @csrf
            <input type="hidden" name="document" value="{{ $document->slug }}">
            <h2 class="font-semibold">{{ $document->slug === 'terms' ? 'Terms & Conditions' : 'Privacy Policy' }}</h2>
            <label class="block text-sm font-medium">Title
                <input name="title" required maxlength="100" value="{{ old('document') === $document->slug ? old('title', $document->title) : $document->title }}" class="mt-1 w-full rounded-lg border border-slate-200 p-3 text-sm">
            </label>
            <label class="block text-sm font-medium">Content
                <textarea name="content" required minlength="50" maxlength="30000" rows="18" class="mt-1 w-full rounded-lg border border-slate-200 p-3 text-sm leading-relaxed">{{ old('document') === $document->slug ? old('content', $document->content) : $document->content }}</textarea>
            </label>
            <div class="flex items-center justify-between gap-4">
                <input type="hidden" name="is_draft" value="0">
                <label class="flex items-center gap-2 text-sm text-slate-600"><input type="checkbox" name="is_draft" value="1" @checked($document->is_draft)> Draft for client review</label>
                <button class="bg-[#087CFE] text-white rounded-lg px-5 py-2 text-sm font-semibold">Save</button>
            </div>
        </form>
    </section>
    @endforeach
</div>
@endsection
