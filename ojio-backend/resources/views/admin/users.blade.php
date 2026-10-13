@extends('admin.layout')

@section('content')
<div class="space-y-6">
    <div class="flex items-center justify-between">
        <div>
            <h1 class="text-xl font-bold text-[#0F172A]">Users</h1>
        </div>
        <div class="text-xs text-[#64748B] font-semibold">
            Total Users: <strong class="text-[#0F172A]">{{ $users->total() }}</strong>
        </div>
    </div>

    <!-- Users Table (Privacy Compliant: User Name, Registered City, Quota Status, Account Status) -->
    <div class="bg-white border border-[#E2E8F0] shadow-sm">
        <table class="w-full text-left text-xs text-[#0F172A]">
            <thead class="bg-[#F8FAFC] text-[#64748B] uppercase font-bold text-[11px] border-b border-[#E2E8F0]">
                <tr>
                    <th class="p-3.5">User</th>
                    <th class="p-3.5">City</th>
                    <th class="p-3.5">Ads Posted</th>
                    <th class="p-3.5">Tier Status</th>
                    <th class="p-3.5">Account Status</th>
                    <th class="p-3.5 text-right">Moderation</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-[#E2E8F0]">
                @forelse($users as $u)
                    <tr class="hover:bg-[#F8FAFC] transition">
                        <td class="p-3.5 font-semibold text-[#0F172A]">
                            <div class="flex items-center gap-3">
                                <div class="w-8 h-8 bg-slate-100 text-[#0F172A] font-bold flex items-center justify-center text-xs border border-[#E2E8F0]">
                                    {{ strtoupper(substr($u->name, 0, 1)) }}
                                </div>
                                <div>
                                    <div class="font-bold text-xs">{{ $u->name }}</div>
                                    <div class="text-[10px] text-[#64748B]">User ID: #{{ $u->id }}</div>
                                </div>
                            </div>
                        </td>
                        <td class="p-3.5 text-[#64748B]">
                            {{ $u->city ?? 'Not specified' }}
                        </td>
                        <td class="p-3.5 font-bold text-[#0F172A]">
                            {{ $u->listings_count ?? 0 }}
                        </td>
                        <td class="p-3.5">
                            @if($u->paid_ads_quota > 0 && $u->canPostFreeAd() && ($u->paid_quota_until === null || $u->paid_quota_until->isFuture()))
                                <span class="px-2 py-0.5 bg-slate-100 text-[#0F172A] font-semibold text-[10px] border border-[#CBD5E1]">
                                    Paid credits: {{ $u->paid_ads_quota }}
                                </span>
                            @else
                                <span class="px-2 py-0.5 bg-emerald-50 text-emerald-700 font-semibold text-[10px] border border-emerald-200">
                                    {{ $u->free_ads_posted >= 2 ? 'Free quota used' : 'Free ads: ' . $u->free_ads_posted . '/2 used' }}
                                </span>
                            @endif
                        </td>
                        <td class="p-3.5">
                            @if($u->is_blocked)
                                <span class="px-2 py-0.5 bg-rose-50 text-rose-700 font-bold text-[10px] border border-rose-200">SUSPENDED</span>
                            @else
                                <span class="px-2 py-0.5 bg-emerald-50 text-emerald-700 font-bold text-[10px] border border-emerald-200">ACTIVE</span>
                            @endif
                        </td>
                        <td class="p-3.5 text-right">
                            <form action="/admin/users/{{ $u->id }}/toggle-block" method="POST" class="inline">
                                @csrf
                                @if($u->role === 'admin')
                                    <span class="text-[#64748B]">Administrator</span>
                                @elseif($u->is_blocked)
                                    <button type="submit" class="px-3 py-1 bg-emerald-600 text-white hover:bg-emerald-700 text-xs font-semibold transition">
                                        Lift Suspension
                                    </button>
                                @else
                                    <button type="submit" class="px-3 py-1 bg-rose-600 text-white hover:bg-rose-700 text-xs font-semibold transition">
                                        Suspend User
                                    </button>
                                @endif
                            </form>
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="6" class="p-8 text-center text-[#64748B]">No users registered.</td>
                    </tr>
                @endforelse
            </tbody>
        </table>

        @if($users->hasPages())
            <div class="p-3.5 border-t border-[#E2E8F0] bg-[#F8FAFC]">
                {{ $users->links() }}
            </div>
        @endif
    </div>
</div>
@endsection
