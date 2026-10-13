@extends('admin.layout')

@section('content')
<div class="space-y-6">
    <div class="flex items-center justify-between">
        <div>
            <h1 class="text-xl font-bold text-[#0F172A]">Coupons</h1>
        </div>
    </div>

    <!-- Create Coupon Form -->
    <div class="bg-white border border-[#E2E8F0] shadow-sm p-6">
        <h2 class="font-bold text-sm text-[#0F172A] mb-4 flex items-center gap-2">
            <i class="fa-solid fa-plus-circle text-[#087CFE]"></i>
            <span>Add Coupon</span>
        </h2>
        <form action="/admin/coupons" method="POST" class="grid grid-cols-1 md:grid-cols-4 gap-4 text-xs">
            @csrf
            <div>
                <label class="block font-bold text-[#0F172A] mb-1.5">Coupon Code *</label>
                <input type="text" name="code" required placeholder="e.g. WELCOME50, OJIOFREE" 
                       class="w-full px-3 py-2.5 border border-[#CBD5E1] focus:border-[#087CFE] focus:outline-none font-mono uppercase bg-white">
            </div>
            <div>
                <label class="block font-bold text-[#0F172A] mb-1.5">Discount Type *</label>
                <select name="type" required class="w-full px-3 py-2.5 border border-[#CBD5E1] focus:border-[#087CFE] focus:outline-none bg-white">
                    <option value="fixed">Flat Discount (INR Amount)</option>
                    <option value="percentage">Percentage Discount (%)</option>
                </select>
            </div>
            <div>
                <label class="block font-bold text-[#0F172A] mb-1.5">Discount Value *</label>
                <input type="number" step="0.01" name="value" required placeholder="e.g. 50 or 100" 
                       class="w-full px-3 py-2.5 border border-[#CBD5E1] focus:border-[#087CFE] focus:outline-none bg-white">
            </div>
            <div>
                <label class="block font-bold text-[#0F172A] mb-1.5">Usage Limit (0 for unlimited)</label>
                <input type="number" name="usage_limit" value="100" 
                       class="w-full px-3 py-2.5 border border-[#CBD5E1] focus:border-[#087CFE] focus:outline-none bg-white">
            </div>
            <div class="md:col-span-2">
                <label class="block font-bold text-[#0F172A] mb-1.5">Offer Description / Benefit *</label>
                <input type="text" name="description" required placeholder="e.g. Rs 50 off on Featured Ad placement for new users" 
                       class="w-full px-3 py-2.5 border border-[#CBD5E1] focus:border-[#087CFE] focus:outline-none bg-white">
            </div>
            <div>
                <label class="block font-bold text-[#0F172A] mb-1.5">Expiry Date (Optional)</label>
                <input type="date" name="expires_at" 
                       class="w-full px-3 py-2.5 border border-[#CBD5E1] focus:border-[#087CFE] focus:outline-none bg-white">
            </div>
            <div class="flex items-center space-x-4 pt-6">
                <label class="flex items-center space-x-2 cursor-pointer select-none">
                    <input type="checkbox" name="show_on_landing" value="1" checked class="w-4 h-4 text-[#087CFE] border-[#CBD5E1] focus:ring-0">
                    <span class="text-xs font-semibold text-[#0F172A]">Show on Landing Page</span>
                </label>
                <label class="flex items-center space-x-2 cursor-pointer select-none">
                    <input type="checkbox" name="show_in_app" value="1" checked class="w-4 h-4 text-[#087CFE] border-[#CBD5E1] focus:ring-0">
                    <span class="text-xs font-semibold text-[#0F172A]">Show in Mobile App</span>
                </label>
            </div>
            <div class="md:col-span-4 flex justify-end pt-2">
                <button type="submit" class="px-5 py-2.5 bg-[#087CFE] hover:bg-[#0066D6] text-white font-bold transition flex items-center gap-2">
                    <i class="fa-solid fa-plus"></i>
                    <span>Create Coupon</span>
                </button>
            </div>
        </form>
    </div>

    <!-- Active Offers Table -->
    <div class="bg-white border border-[#E2E8F0] shadow-sm">
        <div class="p-4 border-b border-[#E2E8F0] flex items-center justify-between">
            <h2 class="font-bold text-sm text-[#0F172A]">All Coupons</h2>
            <span class="text-xs text-[#64748B]">{{ count($coupons) }} coupons available</span>
        </div>
        <div class="overflow-x-auto">
            <table class="w-full text-left text-xs text-[#0F172A]">
                <thead class="bg-[#F8FAFC] text-[#64748B] uppercase font-bold text-[11px] border-b border-[#E2E8F0]">
                    <tr>
                        <th class="p-3.5">Code</th>
                        <th class="p-3.5">Discount</th>
                        <th class="p-3.5">Description</th>
                        <th class="p-3.5">Placements</th>
                        <th class="p-3.5">Usage</th>
                        <th class="p-3.5">Expiry</th>
                        <th class="p-3.5">Status</th>
                        <th class="p-3.5 text-right">Actions</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-[#E2E8F0]">
                    @forelse($coupons as $coupon)
                        <tr class="hover:bg-[#F8FAFC] transition">
                            <td class="p-3.5 font-mono font-bold text-[#087CFE]">
                                <span class="px-2 py-1 bg-blue-50 border border-blue-200">{{ $coupon->code }}</span>
                            </td>
                            <td class="p-3.5 font-bold">
                                @if($coupon->type == 'percentage')
                                    {{ $coupon->value }}% OFF
                                @else
                                    Rs {{ number_format($coupon->value, 2) }} FLAT
                                @endif
                            </td>
                            <td class="p-3.5 text-[#64748B] max-w-xs">{{ $coupon->description }}</td>
                            <td class="p-3.5">
                                <div class="flex items-center gap-1.5 flex-wrap">
                                    @if($coupon->show_on_landing)
                                        <span class="px-1.5 py-0.5 bg-emerald-50 text-emerald-700 text-[10px] font-bold border border-emerald-200">Web</span>
                                    @endif
                                    @if($coupon->show_in_app)
                                        <span class="px-1.5 py-0.5 bg-indigo-50 text-indigo-700 text-[10px] font-bold border border-indigo-200">App</span>
                                    @endif
                                </div>
                            </td>
                            <td class="p-3.5 font-medium">
                                {{ $coupon->times_used }} / {{ $coupon->usage_limit ?: 'Unlimited' }}
                            </td>
                            <td class="p-3.5 text-[#64748B]">
                                {{ $coupon->expires_at ? $coupon->expires_at->format('M d, Y') : 'No Expiry' }}
                            </td>
                            <td class="p-3.5">
                                @if($coupon->isValid())
                                    <span class="px-2 py-0.5 bg-emerald-50 text-emerald-700 text-[10px] font-bold border border-emerald-200">Active</span>
                                @else
                                    <span class="px-2 py-0.5 bg-rose-50 text-rose-700 text-[10px] font-bold border border-rose-200">{{ !$coupon->is_active ? 'Paused' : ($coupon->expires_at?->isPast() ? 'Expired' : 'Limit reached') }}</span>
                                @endif
                            </td>
                            <td class="p-3.5 text-right">
                                <div class="flex items-center justify-end gap-2">
                                    <form action="/admin/coupons/{{ $coupon->id }}/toggle" method="POST" class="inline">
                                        @csrf
                                        <button type="submit" class="px-2.5 py-1 text-[11px] font-bold border {{ $coupon->is_active ? 'border-amber-300 text-amber-700 bg-amber-50 hover:bg-amber-100' : 'border-emerald-300 text-emerald-700 bg-emerald-50 hover:bg-emerald-100' }} transition">
                                            {{ $coupon->is_active ? 'Pause' : 'Activate' }}
                                        </button>
                                    </form>
                                    <form action="{{ route('admin.coupons.delete', $coupon->id) }}" method="POST" class="inline" onsubmit="return confirm('Delete this coupon?');">
                                        @csrf
                                        <button type="submit" class="px-2.5 py-1 text-[11px] font-bold border border-rose-200 text-rose-600 bg-rose-50 hover:bg-rose-100 transition">
                                            Delete
                                        </button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="8" class="p-8 text-center text-[#64748B]">
                                <i class="fa-solid fa-ticket text-3xl mb-2 text-slate-300 block"></i>
                                No promotional coupons found. Create your first coupon above.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
</div>
@endsection
