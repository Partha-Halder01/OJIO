@extends('admin.layout')

@section('content')
<div class="space-y-6">
    <div class="flex items-center justify-between">
        <h1 class="text-xl font-bold">Overview</h1>
        <a href="{{ route('admin.listings', ['status' => 'pending']) }}" class="px-4 py-2 bg-[#087CFE] text-white text-xs font-semibold">Review Ads</a>
    </div>
    <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        @foreach(['active_listings' => 'Active Listings', 'pending_listings' => 'Pending Review', 'total_users' => 'Users', 'total_revenue' => 'Premium Revenue'] as $key => $label)
            <div class="p-5 bg-white border border-[#E2E8F0] rounded-xl">
                <div class="text-xs font-semibold text-[#64748B]">{{ $label }}</div>
                <div class="mt-2 text-2xl font-bold">{{ $key === 'total_revenue' ? '₹ ' : '' }}{{ number_format($stats[$key], $key === 'total_revenue' ? 2 : 0) }}</div>
            </div>
        @endforeach
    </div>
    <div class="bg-white border border-[#E2E8F0]">
        <div class="p-4 flex items-center justify-between border-b border-[#E2E8F0]">
            <h2 class="font-semibold text-sm">Recent Listings</h2>
            <a href="{{ route('admin.listings') }}" class="text-xs text-[#087CFE]">View all</a>
        </div>
        <div class="overflow-x-auto">
            <table class="w-full text-left text-xs">
                <thead class="bg-[#F8FAFC] text-[#64748B]"><tr><th class="p-4">Listing</th><th class="p-4">Seller</th><th class="p-4">Category</th><th class="p-4">Status</th><th class="p-4 text-right">Price</th></tr></thead>
                <tbody class="divide-y divide-[#E2E8F0]">
                    @forelse($recentListings as $listing)
                        <tr><td class="p-4 font-semibold">{{ $listing->title }}</td><td class="p-4">{{ $listing->user?->name ?? 'Unavailable' }}</td><td class="p-4">{{ $listing->category?->name ?? 'Uncategorised' }}</td><td class="p-4">{{ ucfirst($listing->status) }}</td><td class="p-4 text-right">₹{{ number_format($listing->price, 2) }}</td></tr>
                    @empty
                        <tr><td colspan="5" class="p-6 text-center text-[#64748B]">No listings yet.</td></tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
</div>
@endsection
