<section class="mb-6 bg-white border border-[#E2E8F0] p-5 space-y-4">
    <div class="flex justify-between items-center gap-4">
        <h2 class="font-bold text-[#0F172A]">Wallet activity</h2>
        <span class="text-sm text-[#64748B]">Customer balances: <strong>₹{{ number_format($walletBalance, 2) }}</strong></span>
    </div>
    <div class="overflow-x-auto">
        <table class="w-full text-sm text-left">
            <thead><tr class="border-b text-[#64748B]"><th class="p-2">Customer</th><th class="p-2">Description</th><th class="p-2">Amount</th><th class="p-2">Balance after</th><th class="p-2">Date</th></tr></thead>
            <tbody>
                @forelse($walletTransactions as $transaction)
                    <tr class="border-b"><td class="p-2">{{ $transaction->name }}</td><td class="p-2">{{ $transaction->description }}</td><td class="p-2">₹{{ number_format($transaction->amount_paise / 100, 2) }}</td><td class="p-2">₹{{ number_format($transaction->balance_paise / 100, 2) }}</td><td class="p-2">{{ $transaction->created_at }}</td></tr>
                @empty
                    <tr><td colspan="5" class="p-4 text-[#64748B]">No wallet transactions yet.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
</section>
