@extends('admin.layout')

@section('content')
<div class="space-y-6">
    <div class="flex items-center justify-between">
        <div>
            <h1 class="text-xl font-bold text-[#0F172A]">Listings</h1>
        </div>
        <div class="text-xs text-[#64748B] font-semibold">
            Total Listings: <strong class="text-[#0F172A]">{{ $listings->total() }}</strong>
        </div>
    </div>

    <div class="bg-white border border-[#E2E8F0] shadow-sm p-4 flex flex-wrap items-center gap-2" aria-label="Filter by posting date">
        <span class="text-xs font-semibold text-[#64748B] mr-2">Posted</span>
        @foreach(['all' => 'All Time', 'today' => 'Today', 'yesterday' => 'Yesterday', '7_days' => 'Last 7 Days', '30_days' => 'Last 30 Days'] as $value => $label)
            <a href="{{ route('admin.listings', array_merge(request()->only(['status', 'parent_id', 'category_id']), ['period' => $value])) }}"
               @if($period === $value) aria-current="true" @endif
               class="px-3 py-2 rounded text-xs font-semibold border transition {{ $period === $value ? 'bg-[#087CF5] border-[#087CF5] text-white' : 'bg-white border-[#E2E8F0] text-[#64748B] hover:border-[#087CF5] hover:text-[#087CF5]' }}">
                {{ $label }}
            </a>
        @endforeach
    </div>

    <!-- Listings Filter Tabs -->
    <div class="flex justify-between items-center border-b border-[#E2E8F0]">
        <div class="flex flex-wrap gap-x-4 gap-y-3 text-xs font-semibold">
            <a href="{{ route('admin.listings', array_merge(request()->only(['parent_id', 'category_id', 'period']), ['status' => 'all'])) }}" class="pb-3 {{ !request('status') || request('status') == 'all' ? 'border-b-2 border-[#087CF5] text-[#087CF5] font-bold' : 'text-[#64748B] hover:text-[#0F172A]' }}">
                All Listings
            </a>
            <a href="{{ route('admin.listings', array_merge(request()->only(['parent_id', 'category_id', 'period']), ['status' => 'active'])) }}" class="pb-3 {{ request('status') == 'active' ? 'border-b-2 border-[#087CF5] text-[#087CF5] font-bold' : 'text-[#64748B] hover:text-[#0F172A]' }}">
                Active
            </a>
            <a href="{{ route('admin.listings', array_merge(request()->only(['parent_id', 'category_id', 'period']), ['status' => 'rejected'])) }}" class="pb-3 {{ request('status') == 'rejected' ? 'border-b-2 border-[#087CF5] text-[#087CF5] font-bold' : 'text-[#64748B] hover:text-[#0F172A]' }}">
                Rejected
            </a>
            <a href="{{ route('admin.listings', array_merge(request()->only(['parent_id', 'category_id', 'period']), ['status' => 'pending'])) }}" class="pb-3 {{ request('status') == 'pending' ? 'border-b-2 border-[#087CF5] text-[#087CF5]' : 'text-[#64748B]' }}">Pending</a>
            <a href="{{ route('admin.listings', array_merge(request()->only(['parent_id', 'category_id', 'period']), ['status' => 'sold'])) }}" class="pb-3 {{ request('status') == 'sold' ? 'border-b-2 border-[#087CF5] text-[#087CF5]' : 'text-[#64748B]' }}">Sold</a>
        </div>
        <form method="GET" class="pb-2 flex gap-3">
            @if(request('status'))
                <input type="hidden" name="status" value="{{ request('status') }}">
            @endif
            <input type="hidden" name="period" value="{{ $period }}">
            <select name="parent_id" onchange="this.form.category_id.value=''; this.form.submit()" class="border border-[#E2E8F0] bg-white rounded text-xs px-2 py-1 font-bold text-[#0F172A] outline-none focus:border-[#087CFE] w-48">
                <option value="">All Main Categories</option>
                @foreach($parentCategories as $cat)
                    <option value="{{ $cat->id }}" {{ request('parent_id') == $cat->id ? 'selected' : '' }}>
                        {{ $cat->name }}
                    </option>
                @endforeach
            </select>

            <select name="category_id" onchange="this.form.submit()" class="border border-[#E2E8F0] bg-white rounded text-xs px-2 py-1 font-bold text-[#0F172A] outline-none focus:border-[#087CFE] w-48" {{ !$subCategories->isNotEmpty() ? 'disabled' : '' }}>
                @if($subCategories->isNotEmpty())
                    <option value="">All Subcategories</option>
                    @foreach($subCategories as $sub)
                        <option value="{{ $sub->id }}" {{ request('category_id') == $sub->id ? 'selected' : '' }}>
                            {{ $sub->name }}
                        </option>
                    @endforeach
                @else
                    <option value="">Select Main Category First</option>
                @endif
            </select>
        </form>
    </div>

    <!-- Listings Table -->
    <div class="bg-white border border-[#E2E8F0] shadow-sm">
        <table class="w-full text-left text-xs text-[#0F172A]">
            <thead class="bg-[#F8FAFC] text-[#64748B] uppercase font-bold text-[11px] border-b border-[#E2E8F0]">
                <tr>
                    <th class="p-3.5">Item Details</th>
                    <th class="p-3.5">Seller</th>
                    <th class="p-3.5">Location</th>
                    <th class="p-3.5">Price</th>
                    <th class="p-3.5">Status</th>
                    <th class="p-3.5 text-right">Moderation Action</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-[#E2E8F0]">
                @forelse($listings as $item)
                    <tr class="hover:bg-[#F8FAFC] transition">
                        <td class="p-3.5">
                            <div class="flex items-center gap-3">
                                @if($item->images && count($item->images) > 0)
                                    <img src="{{ $item->images[0]->image_path }}" 
                                         class="w-11 h-11 object-cover border border-[#E2E8F0]"
                                         onerror="this.src='https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=200'">
                                @else
                                    <div class="w-11 h-11 bg-slate-100 flex items-center justify-center text-slate-400 border border-[#E2E8F0]">
                                        <i class="fa-solid fa-image"></i>
                                    </div>
                                @endif
                                <div>
                                    <div class="font-bold text-[#0F172A] text-xs">{{ $item->title }}</div>
                                    <div class="text-[10px] text-[#64748B]">{{ $item->category->name ?? 'Marketplace' }}</div>
                                </div>
                            </div>
                        </td>
                        <td class="p-3.5 font-semibold text-[#0F172A]">
                            {{ $item->user->name ?? 'Verified Seller' }}
                        </td>
                        <td class="p-3.5 text-[#64748B]">
                            {{ $item->locality ? $item->locality . ', ' : '' }}{{ $item->city }}
                        </td>
                        <td class="p-3.5 font-bold text-[#0F172A]">
                            ₹ {{ number_format($item->price) }}
                        </td>
                        <td class="p-3.5">
                            @php
                                $statusStyle = match ($item->status) {
                                    'active' => 'bg-emerald-50 text-emerald-700 border-emerald-200',
                                    'pending' => 'bg-amber-50 text-amber-700 border-amber-200',
                                    'sold' => 'bg-blue-50 text-blue-700 border-blue-200',
                                    'rejected' => 'bg-rose-50 text-rose-700 border-rose-200',
                                    default => 'bg-slate-50 text-slate-700 border-slate-200',
                                };
                            @endphp
                            <span class="px-2 py-0.5 text-[10px] font-semibold border rounded {{ $statusStyle }}">{{ ucfirst($item->status) }}</span>
                        </td>
                        <td class="p-3.5 text-right">
                            <form action="/admin/listings/{{ $item->id }}/status" method="POST" class="inline-flex gap-2">
                                @csrf
                                @if($item->status === 'active')
                                    <input type="hidden" name="status" value="rejected">
                                    <button type="submit" class="px-3 py-1 bg-rose-50 text-rose-700 border border-rose-200 hover:bg-rose-100 text-xs font-semibold transition">
                                        Reject
                                    </button>
                                @elseif(in_array($item->status, ['pending', 'rejected']))
                                    <button type="submit" name="status" value="active" class="px-3 py-1 bg-emerald-600 text-white hover:bg-emerald-700 text-xs font-semibold transition">
                                        Approve
                                    </button>
                                    @if($item->status === 'pending')
                                        <button type="submit" name="status" value="rejected" class="px-3 py-1 bg-rose-50 text-rose-700 border border-rose-200 text-xs font-semibold">Reject</button>
                                    @endif
                                @endif
                            </form>
                            @if(in_array($item->status, ['sold', 'expired']))
                                <span class="text-[#64748B]">Closed</span>
                            @endif
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="6" class="p-8 text-center text-[#64748B]">No listings matching criteria.</td>
                    </tr>
                @endforelse
            </tbody>
        </table>

        @if($listings->hasPages())
            <div class="p-3.5 border-t border-[#E2E8F0] bg-[#F8FAFC]">
                {{ $listings->links() }}
            </div>
        @endif
    </div>
</div>
@endsection
