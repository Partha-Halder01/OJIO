@extends('admin.layout')

@section('content')
<div class="space-y-6">
    <div class="flex items-center justify-between">
        <div>
            <h1 class="text-xl font-bold text-[#0F172A]">Payments & Packages</h1>
        </div>
        <div class="text-xs text-[#64748B] font-semibold">
            Total Transactions: <strong class="text-[#0F172A]">{{ $orders->total() }}</strong>
        </div>
    </div>
    @include('admin.wallet_ledger')
    <!-- Monetization Overview Metrics -->
    <div class="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div class="p-5 bg-white border border-[#E2E8F0] shadow-sm">
            <div class="flex items-center justify-between text-[#64748B]">
                <span class="text-xs font-bold uppercase tracking-wider">Total Revenue</span>
                <i class="fa-solid fa-indian-rupee-sign text-slate-400 text-sm"></i>
            </div>
            <div class="text-2xl font-bold text-[#0F172A] mt-2">₹ {{ number_format($totalRevenue, 2) }}</div>
            <div class="text-[11px] text-[#64748B] mt-1">Paid ad listings & packages</div>
        </div>

        <div class="p-5 bg-white border border-[#E2E8F0] shadow-sm">
            <div class="flex items-center justify-between text-[#64748B]">
                <span class="text-xs font-bold uppercase tracking-wider">Free Ad Quota</span>
                <i class="fa-solid fa-shield-halved text-slate-400 text-sm"></i>
            </div>
            <form method="POST" action="{{ route('admin.free-quota.update') }}" class="mt-3 flex gap-2 items-center">
                @csrf
                <input aria-label="Free ad quota" type="number" name="free_ads_limit" value="{{ old('free_ads_limit', $freeAdsLimit) }}" min="0" max="1000" required class="w-20 border border-[#E2E8F0] px-2 py-1.5 text-sm font-bold rounded">
                <button type="submit" class="bg-[#087CF5] text-white text-xs font-bold px-3 py-2 rounded">Save</button>
            </form>
            <div class="text-[11px] text-[#64748B] mt-2">Restores 30 days after the free quota is used.</div>
        </div>

        <div class="p-5 bg-white border border-[#E2E8F0] shadow-sm">
            <div class="flex items-center justify-between text-[#64748B]">
                <span class="text-xs font-bold uppercase tracking-wider">Premium Members</span>
                <i class="fa-solid fa-gem text-blue-500 text-sm"></i>
            </div>
            <div class="text-2xl font-bold text-[#087CF5] mt-2">{{ $premiumUsersCount }}</div>
            <div class="text-[11px] text-[#64748B] mt-1">Diamond badge & paid quotas</div>
        </div>

        <div class="p-5 bg-white border border-[#E2E8F0] shadow-sm">
            <div class="flex items-center justify-between text-[#64748B]">
                <span class="text-xs font-bold uppercase tracking-wider">Active Packages</span>
                <i class="fa-solid fa-box-open text-slate-400 text-sm"></i>
            </div>
            <div class="text-2xl font-bold text-[#0F172A] mt-2">{{ $packages->count() }} Tiers</div>
            <div class="text-[11px] text-[#64748B] mt-1">Configurable Razorpay plans</div>
        </div>
    </div>

    <!-- Package Price & Text Configuration Section -->
    <div class="bg-white border border-[#E2E8F0] shadow-sm p-5 space-y-4">
        <div class="flex items-center justify-between border-b border-[#E2E8F0] pb-3">
            <div>
                <h2 class="font-bold text-sm text-[#0F172A] flex items-center gap-2">
                    <i class="fa-solid fa-sliders text-[#087CF5]"></i>
                    Packages
                </h2>
            </div>
            <span class="text-xs bg-blue-50 text-[#087CF5] border border-blue-200 px-2.5 py-1 font-semibold">
                Mobile Paywall
            </span>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-5 pt-2">
            @foreach($packages as $pkg)
                <div class="border {{ $pkg->badge_enabled ? 'border-blue-300 bg-gradient-to-b from-blue-50/40 to-white' : 'border-[#E2E8F0] bg-[#F8FAFC]' }} p-4 relative">
                    @if($pkg->badge_enabled)
                        <div class="absolute -top-2.5 right-3 bg-[#087CF5] text-white text-[10px] font-bold px-2 py-0.5 shadow-sm uppercase tracking-wider">
                            💎 Diamond Badge Included
                        </div>
                    @endif

                    <form action="{{ route('admin.packages.update', $pkg->id) }}" method="POST" class="space-y-3">
                        @csrf
                        <div>
                            <label class="block text-[11px] font-bold text-[#64748B] uppercase">Plan Key</label>
                            <input type="text" value="{{ $pkg->key }}" disabled class="w-full mt-1 bg-slate-100 text-slate-500 font-mono text-xs border border-slate-200 px-2.5 py-1.5 cursor-not-allowed">
                        </div>

                        <div>
                            <label class="block text-[11px] font-bold text-[#0F172A] uppercase">Display Title</label>
                            <input type="text" name="name" value="{{ $pkg->name }}" required class="w-full mt-1 bg-white text-[#0F172A] text-xs font-semibold border border-[#E2E8F0] px-2.5 py-1.5 focus:border-[#087CF5] focus:ring-1 focus:ring-[#087CF5] outline-none">
                        </div>

                        <div class="grid grid-cols-2 gap-2">
                            <div>
                                <label class="block text-[11px] font-bold text-[#0F172A] uppercase">Price (₹ INR)</label>
                                <div class="relative mt-1">
                                    <span class="absolute inset-y-0 left-0 pl-2.5 flex items-center text-xs text-[#64748B] font-bold">₹</span>
                                    <input type="number" step="1" name="price" value="{{ round($pkg->price) }}" required class="w-full pl-6 bg-white text-[#0F172A] text-xs font-bold border border-[#E2E8F0] py-1.5 focus:border-[#087CF5] focus:ring-1 focus:ring-[#087CF5] outline-none">
                                </div>
                            </div>
                            <div>
                                <label class="block text-[11px] font-bold text-[#0F172A] uppercase">Ad Limit</label>
                                <input type="number" name="ads_limit" value="{{ $pkg->ads_limit }}" class="w-full mt-1 bg-white text-[#0F172A] text-xs border border-[#E2E8F0] px-2.5 py-1.5 focus:border-[#087CF5] outline-none" min="0" placeholder="0 = Unlimited">
                            </div>
                        </div>

                        <div>
                            <label class="block text-[11px] font-bold text-[#0F172A] uppercase">Duration (Days)</label>
                            <input type="number" name="duration_days" value="{{ $pkg->duration_days }}" class="w-full mt-1 bg-white text-[#0F172A] text-xs border border-[#E2E8F0] px-2.5 py-1.5 focus:border-[#087CF5] outline-none" min="0" placeholder="0 = No Expiry">
                        </div>

                        <div>
                            <label class="block text-[11px] font-bold text-[#0F172A] uppercase">Description / Perks</label>
                            <textarea name="description" rows="2" class="w-full mt-1 bg-white text-[#0F172A] text-xs border border-[#E2E8F0] px-2.5 py-1.5 focus:border-[#087CF5] outline-none">{{ $pkg->description }}</textarea>
                        </div>

                        <button type="submit" class="w-full bg-[#087CF5] hover:bg-blue-600 text-white font-bold text-xs py-2 transition shadow-sm flex items-center justify-center gap-1.5">
                            <i class="fa-solid fa-floppy-disk"></i>
                            Save
                        </button>
                    </form>
                </div>
            @endforeach
        </div>
    </div>

    <!-- Active Premium Members Table -->
    @if(isset($premiumUsers) && $premiumUsers->count() > 0)
    <div class="bg-white border border-[#E2E8F0] shadow-sm">
        <div class="p-4 border-b border-[#E2E8F0] flex items-center justify-between">
            <h2 class="font-bold text-sm text-[#0F172A] flex items-center gap-2">
                <i class="fa-solid fa-crown text-amber-500"></i>
                Premium Sellers
            </h2>
            <span class="text-xs text-[#64748B]">{{ $premiumUsersCount }} Total Subscribers</span>
        </div>

        <table class="w-full text-left text-xs text-[#0F172A]">
            <thead class="bg-[#F8FAFC] text-[#64748B] uppercase font-bold text-[11px] border-b border-[#E2E8F0]">
                <tr>
                    <th class="p-3.5">User</th>
                    <th class="p-3.5">Email / Phone</th>
                    <th class="p-3.5">Badge</th>
                    <th class="p-3.5">Paid Ads Quota</th>
                    <th class="p-3.5">Expires On</th>
                    <th class="p-3.5 text-right">Joined</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-[#E2E8F0]">
                @foreach($premiumUsers as $u)
                    <tr class="hover:bg-[#F8FAFC] transition">
                        <td class="p-3.5 font-bold text-[#0F172A] flex items-center gap-2">
                            <span>{{ $u->name }}</span>
                            @if($u->has_diamond_badge)
                                <span class="text-[10px] bg-blue-100 text-blue-700 px-1.5 py-0.5 font-bold flex items-center gap-1">
                                    💎 Diamond
                                </span>
                            @endif
                        </td>
                        <td class="p-3.5 text-[#64748B]">{{ $u->email ?? $u->phone ?? 'N/A' }}</td>
                        <td class="p-3.5">
                            @if($u->is_premium)
                                <span class="px-2 py-0.5 text-[10px] font-bold uppercase bg-amber-50 text-amber-700 border border-amber-200">
                                    Premium Plan
                                </span>
                            @else
                                <span class="px-2 py-0.5 text-[10px] font-semibold text-[#64748B] bg-slate-100">Standard</span>
                            @endif
                        </td>
                        <td class="p-3.5 font-semibold text-[#087CF5]">{{ $u->paid_ads_quota > 0 ? $u->paid_ads_quota . ' remaining' : ($u->has_diamond_badge ? 'Unlimited' : '0') }}</td>
                        <td class="p-3.5 text-[#64748B]">{{ $u->premium_until ? \Carbon\Carbon::parse($u->premium_until)->format('M d, Y') : 'Lifetime / Per Ad' }}</td>
                        <td class="p-3.5 text-right text-[#64748B]">{{ $u->created_at->format('M d, Y') }}</td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>
    @endif

    <!-- Monetization Orders Ledger -->
    <div class="bg-white border border-[#E2E8F0] shadow-sm">
        <div class="p-4 border-b border-[#E2E8F0] flex items-center justify-between">
            <h2 class="font-bold text-sm text-[#0F172A] flex items-center gap-2">
                <i class="fa-solid fa-receipt text-slate-500"></i>
                Payment History
            </h2>
            <span class="text-xs text-[#64748B]">{{ $orders->total() }} Total Records</span>
        </div>

        <table class="w-full text-left text-xs text-[#0F172A]">
            <thead class="bg-[#F8FAFC] text-[#64748B] uppercase font-bold text-[11px] border-b border-[#E2E8F0]">
                <tr>
                    <th class="p-3.5">Transaction ID</th>
                    <th class="p-3.5">User</th>
                    <th class="p-3.5">Details</th>
                    <th class="p-3.5">Coupon</th>
                    <th class="p-3.5">Amount Paid</th>
                    <th class="p-3.5">Provider</th>
                    <th class="p-3.5">Status</th>
                    <th class="p-3.5 text-right">Date</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-[#E2E8F0]">
                @forelse($orders as $o)
                    <tr class="hover:bg-[#F8FAFC] transition">
                        <td class="p-3.5 font-mono font-bold text-[#087CF5]">{{ $o->transaction_id }}</td>
                        <td class="p-3.5 font-semibold text-[#0F172A]">{{ $o->user->name ?? 'User #' . $o->user_id }}</td>
                        <td class="p-3.5 max-w-[200px] truncate text-[#64748B]">{{ $o->listing->title ?? ($o->notes ?? 'Package Purchase') }}</td>
                        <td class="p-3.5 text-[#64748B]">
                            @if($o->coupon_code)
                                <span class="font-bold text-[#087CF5] uppercase">{{ $o->coupon_code }}</span><br>
                                <span class="text-[10px] text-green-600 font-bold">-₹{{ number_format($o->discount_amount) }}</span>
                            @else
                                -
                            @endif
                        </td>
                        <td class="p-3.5 font-bold text-[#0F172A]">₹ {{ number_format($o->amount, 2) }}</td>
                        <td class="p-3.5 uppercase text-[10px] text-[#64748B] font-semibold">{{ $o->payment_provider }}</td>
                        <td class="p-3.5">
                            @if($o->payment_status === 'paid')
                                <span class="px-2 py-0.5 text-[10px] font-bold uppercase bg-emerald-50 text-emerald-700 border border-emerald-200">
                                    Paid
                                </span>
                            @else
                                <span class="px-2 py-0.5 text-[10px] font-bold uppercase bg-amber-50 text-amber-700 border border-amber-200">
                                    {{ $o->payment_status }}
                                </span>
                            @endif
                        </td>
                        <td class="p-3.5 text-right text-[#64748B] font-medium">{{ $o->created_at->format('M d, Y H:i') }}</td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="8" class="p-8 text-center text-[#64748B]">No transactions recorded yet.</td>
                    </tr>
                @endforelse
            </tbody>
        </table>

        @if($orders->hasPages())
            <div class="p-3.5 border-t border-[#E2E8F0] bg-[#F8FAFC]">
                {{ $orders->links() }}
            </div>
        @endif
    </div>
</div>
@endsection
