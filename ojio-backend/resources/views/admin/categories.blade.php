@extends('admin.layout')

@section('content')
<div class="space-y-6">
    <div class="flex items-center justify-between">
        <div>
            <h1 class="text-xl font-bold text-[#0F172A]">Categories</h1>
        </div>
        <button onclick="document.getElementById('ad-modal').classList.remove('hidden')" class="px-4 py-2 bg-[#087CFE] text-white text-xs font-bold hover:bg-[#0066D6] transition shadow-sm" {{ $parentCategory?->parent_id ? 'disabled' : '' }}>
            <i class="fa-solid fa-plus mr-1.5"></i> Add {{ $parentCategory ? 'Subcategory' : 'Category' }}
        </button>
    </div>

    <!-- Filters & Breadcrumbs -->
    <div class="flex items-center justify-between bg-white p-3 border border-[#E2E8F0] shadow-sm mb-4">
        <div class="flex items-center text-sm">
            <a href="{{ route('admin.categories') }}" class="font-bold text-[#087CFE] hover:underline">Root Categories</a>
            @foreach($breadcrumbs as $crumb)
                <span class="mx-2 text-slate-400">/</span>
                @if($loop->last)
                    <span class="font-bold text-slate-800">{{ $crumb->name }}</span>
                @else
                    <a href="{{ route('admin.categories', ['parent_id' => $crumb->id]) }}" class="font-bold text-[#087CFE] hover:underline">{{ $crumb->name }}</a>
                @endif
            @endforeach
        </div>

        <form method="GET" class="flex items-center gap-2">
            @if(request('parent_id'))
                <input type="hidden" name="parent_id" value="{{ request('parent_id') }}">
            @endif
            <select name="status" onchange="this.form.submit()" class="border border-[#E2E8F0] bg-white rounded text-xs px-2 py-1 font-bold text-[#0F172A] outline-none focus:border-[#087CFE]">
                <option value="">All Statuses</option>
                <option value="active" {{ request('status') == 'active' ? 'selected' : '' }}>Active Only</option>
                <option value="removed" {{ request('status') == 'removed' ? 'selected' : '' }}>Disabled Only</option>
            </select>
        </form>
    </div>

    <div class="bg-white border border-[#E2E8F0] shadow-sm mb-8">
        <table class="w-full text-left text-xs text-[#0F172A]">
            <thead class="bg-[#F8FAFC] text-[#64748B] uppercase font-bold text-[11px] border-b border-[#E2E8F0]">
                <tr>
                    <th class="p-4">Name / Icon</th>
                    <th class="p-4">Slug / Identifier</th>
                    <th class="p-4">Status</th>
                    <th class="p-4">Listings (Total / Active / Sold)</th>
                    <th class="p-4 text-right">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-[#E2E8F0]">
                @forelse($categoriesList as $cat)
                    <tr class="hover:bg-[#F8FAFC] transition {{ !$cat->is_active ? 'opacity-50' : '' }}">
                        <td class="p-4 font-semibold text-[#0F172A]">
                            <div class="flex items-center gap-3">
                                @if(empty($cat->parent_id))
                                    @if($cat->icon && (str_starts_with($cat->icon, 'http') || str_starts_with($cat->icon, '/')))
                                        <img src="{{ $cat->icon }}" class="w-8 h-8 object-contain" onerror="this.outerHTML='<div class=\'w-8 h-8 bg-blue-50 text-[#087CFE] flex items-center justify-center font-bold text-xs border border-blue-100\'><i class=\'fa-solid fa-layer-group\'></i></div>'">
                                    @else
                                        <div class="w-8 h-8 bg-blue-50 text-[#087CFE] flex items-center justify-center font-bold text-xs border border-blue-100">
                                            <i class="fa-solid fa-layer-group"></i>
                                        </div>
                                    @endif
                                @endif
                                <a href="{{ route('admin.categories', ['parent_id' => $cat->id]) }}" class="text-[#087CFE] hover:underline text-sm font-bold">
                                    {{ $cat->name }}
                                </a>
                            </div>
                        </td>
                        <td class="p-4 font-mono text-[#64748B]">{{ $cat->slug }}</td>
                        <td class="p-4">
                            @if($cat->is_active)
                                <span class="px-2 py-1 bg-green-100 text-green-700 font-bold text-[10px] rounded">Active</span>
                            @else
                                <span class="px-2 py-1 bg-red-100 text-red-700 font-bold text-[10px] rounded">Disabled</span>
                            @endif
                        </td>
                        <td class="p-4">
                            <div class="flex items-center gap-3 font-bold text-[11px]">
                                <span class="text-[#64748B]" title="Total Listings">{{ $cat->listings_count ?? 0 }} Total</span>
                                <span class="text-green-600" title="Active Listings">{{ $cat->active_listings_count ?? 0 }} Active</span>
                                <span class="text-orange-500" title="Sold Listings">{{ $cat->sold_listings_count ?? 0 }} Sold</span>
                            </div>
                        </td>
                        <td class="p-4 text-right">
                            <div class="flex items-center justify-end gap-3">
                                <a href="{{ route('admin.categories', ['parent_id' => $cat->id]) }}" class="text-[#087CFE] font-bold hover:underline">Subcategories</a>
                                <span class="text-slate-300">|</span>
                                <button data-category="{{ json_encode(['id' => $cat->id, 'name' => $cat->name, 'slug' => $cat->slug, 'parent_id' => $cat->parent_id, 'sort_order' => $cat->sort_order, 'brands' => $cat->custom_attributes_schema['brand'] ?? []]) }}" onclick="editCategory(JSON.parse(this.dataset.category))" class="font-bold text-[#64748B] hover:text-[#0F172A]">Edit</button>
                                <span class="text-slate-300">|</span>
                                <form action="{{ route('admin.categories.toggle_status', $cat->id) }}" method="POST" class="inline">
                                    @csrf
                                    <button type="submit" class="font-bold {{ $cat->is_active ? 'text-red-500 hover:text-red-700' : 'text-green-600 hover:text-green-800' }}">
                                        {{ $cat->is_active ? 'Disable' : 'Enable' }}
                                    </button>
                                </form>
                            </div>
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="5" class="p-8 text-center text-[#64748B]">No items found in this category level.</td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    </div>
</div>

<!-- Modal for adding category -->
<div id="ad-modal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center hidden">
    <div class="bg-white p-6 max-w-md w-full border border-[#CBD5E1] shadow-2xl">
        <div class="flex items-center justify-between pb-3 mb-4 border-b border-[#E2E8F0]">
            <h3 class="font-bold text-sm text-[#0F172A]">Add New</h3>
            <button onclick="document.getElementById('ad-modal').classList.add('hidden')" class="text-slate-400 hover:text-slate-600">
                <i class="fa-solid fa-xmark text-sm"></i>
            </button>
        </div>
        <form action="/admin/categories" method="POST" enctype="multipart/form-data" class="space-y-4 text-xs">
            @csrf
            <div>
                <label class="block font-bold text-[#0F172A] mb-1">Name *</label>
                <input type="text" name="name" required placeholder="e.g. Electric Vehicles" class="w-full px-3 py-2 border border-[#CBD5E1] focus:border-[#087CFE] outline-none">
            </div>
            <div>
                <label class="block font-bold text-[#0F172A] mb-1">Slug / Key *</label>
                <input type="text" name="slug" required placeholder="e.g. electric-vehicles" class="w-full px-3 py-2 border border-[#CBD5E1] focus:border-[#087CFE] outline-none font-mono">
            </div>
            <div>
                <label class="block font-bold text-[#0F172A] mb-1">Parent Category</label>
                <select name="parent_id" class="w-full px-3 py-2 border border-[#CBD5E1] focus:border-[#087CFE] outline-none">
                    <option value="">None (Primary Category)</option>
                    @foreach($allPrimary as $parentCat)
                        <option value="{{ $parentCat->id }}" {{ ($parentCategory && $parentCategory->id == $parentCat->id) ? 'selected' : '' }}>{{ $parentCat->name }}</option>
                    @endforeach
                </select>
            </div>
            <div>
                <label class="block font-bold mb-1">Sort order</label>
                <input type="number" name="sort_order" value="0" min="0" max="9999" class="w-full px-3 py-2 border border-[#CBD5E1]">
            </div>
            <div>
                <label class="block font-bold mb-1">Brands (comma-separated)</label>
                <textarea name="brands" rows="2" maxlength="5000" placeholder="Samsung, Apple, Xiaomi" class="w-full px-3 py-2 border border-[#CBD5E1]"></textarea>
            </div>
            <div>
                <label class="block font-bold text-[#0F172A] mb-1">Icon / Logo Image</label>
                <input type="file" name="icon" accept="image/*" class="w-full px-3 py-1.5 border border-[#CBD5E1] focus:border-[#087CFE] outline-none bg-slate-50">
            </div>
            <div class="flex justify-end gap-2 pt-2">
                <button type="button" onclick="document.getElementById('ad-modal').classList.add('hidden')" class="px-4 py-2 border border-[#CBD5E1] text-[#64748B] font-bold">Cancel</button>
                <button type="submit" class="px-4 py-2 bg-[#087CFE] hover:bg-[#0066D6] text-white font-bold">Save</button>
            </div>
        </form>
    </div>
</div>

<!-- Modal for editing category -->
<div id="edit-modal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center hidden">
    <div class="bg-white p-6 max-w-md w-full border border-[#CBD5E1] shadow-2xl">
        <div class="flex items-center justify-between pb-3 mb-4 border-b border-[#E2E8F0]">
            <h3 class="font-bold text-sm text-[#0F172A]">Edit</h3>
            <button onclick="document.getElementById('edit-modal').classList.add('hidden')" class="text-slate-400 hover:text-slate-600">
                <i class="fa-solid fa-xmark text-sm"></i>
            </button>
        </div>
        <form id="edit-form" method="POST" enctype="multipart/form-data" class="space-y-4 text-xs">
            @csrf
            <div>
                <label class="block font-bold text-[#0F172A] mb-1">Name *</label>
                <input type="text" id="edit-name" name="name" required class="w-full px-3 py-2 border border-[#CBD5E1] focus:border-[#087CFE] outline-none">
            </div>
            <div>
                <label class="block font-bold text-[#0F172A] mb-1">Slug / Key *</label>
                <input type="text" id="edit-slug" name="slug" required class="w-full px-3 py-2 border border-[#CBD5E1] focus:border-[#087CFE] outline-none font-mono">
            </div>
            <div>
                <label class="block font-bold text-[#0F172A] mb-1">Parent Category</label>
                <select id="edit-parent" name="parent_id" class="w-full px-3 py-2 border border-[#CBD5E1] focus:border-[#087CFE] outline-none">
                    <option value="">None (Primary Category)</option>
                    @foreach($allPrimary as $parentCat)
                        <option value="{{ $parentCat->id }}">{{ $parentCat->name }}</option>
                    @endforeach
                </select>
            </div>
            <div>
                <label class="block font-bold text-[#0F172A] mb-1">Replace icon (optional)</label>
                <input type="file" name="icon" accept="image/*" class="w-full px-3 py-1.5 border border-[#CBD5E1] focus:border-[#087CFE] outline-none bg-slate-50">
            </div>
            <div>
                <label class="block font-bold mb-1">Sort order</label>
                <input type="number" id="edit-sort" name="sort_order" min="0" max="9999" class="w-full px-3 py-2 border border-[#CBD5E1]">
            </div>
            <div>
                <label class="block font-bold mb-1">Brands (comma-separated)</label>
                <textarea id="edit-brands" name="brands" rows="2" maxlength="5000" class="w-full px-3 py-2 border border-[#CBD5E1]"></textarea>
            </div>
            <div class="flex justify-end gap-2 pt-2">
                <button type="button" onclick="document.getElementById('edit-modal').classList.add('hidden')" class="px-4 py-2 border border-[#CBD5E1] text-[#64748B] font-bold">Cancel</button>
                <button type="submit" class="px-4 py-2 bg-[#087CFE] hover:bg-[#0066D6] text-white font-bold">Update</button>
            </div>
        </form>
    </div>
</div>

<script>
    function editCategory(category) {
        document.getElementById('edit-name').value = category.name;
        document.getElementById('edit-slug').value = category.slug;
        document.getElementById('edit-parent').value = category.parent_id || '';
        document.getElementById('edit-sort').value = category.sort_order || 0;
        document.getElementById('edit-brands').value = Array.isArray(category.brands) ? category.brands.join(', ') : '';
        document.getElementById('edit-form').action = '/admin/categories/' + category.id + '/update';
        document.getElementById('edit-modal').classList.remove('hidden');
    }
</script>
@endsection
