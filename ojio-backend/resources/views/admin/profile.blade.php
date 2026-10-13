@extends('admin.layout')

@section('content')
<div class="space-y-6 max-w-6xl">
    <div>
        <h1 class="text-xl font-bold text-[#0F172A] tracking-tight">Settings</h1>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        <!-- Card 1: Personal & Profile Details -->
        <div class="bg-white border border-[#E2E8F0] shadow-sm p-6">
            <div class="flex items-center gap-3 pb-4 mb-5 border-b border-[#E2E8F0]">
                <div class="w-10 h-10 bg-blue-50 text-[#087CFE] flex items-center justify-center font-bold text-base border border-blue-100">
                    <i class="fa-solid fa-user-pen"></i>
                </div>
                <div>
                    <h2 class="text-sm font-bold text-[#0F172A]">Profile</h2>
                </div>
            </div>

            <form action="{{ route('admin.profile.update') }}" method="POST" class="space-y-4">
                @csrf

                <div>
                    <label class="block text-xs font-bold text-[#0F172A] mb-1.5">Administrator Name</label>
                    <input type="text" name="name" value="{{ old('name', $admin->name) }}" required
                        class="w-full px-3.5 py-2.5 bg-white border border-[#CBD5E1] focus:border-[#087CFE] text-xs font-semibold text-[#0F172A] outline-none transition">
                </div>

                <div>
                    <label class="block text-xs font-bold text-[#0F172A] mb-1.5">Login Email</label>
                    <input type="email" name="email" value="{{ old('email', $admin->email) }}" required
                        class="w-full px-3.5 py-2.5 bg-white border border-[#CBD5E1] focus:border-[#087CFE] text-xs font-semibold text-[#0F172A] outline-none transition">
                    <p class="text-[10px] text-[#64748B] mt-1">This email is used to log in to the admin console.</p>
                </div>

                <div>
                    <label class="block text-xs font-bold text-[#0F172A] mb-1.5">Phone Number</label>
                    <input type="text" name="phone" value="{{ old('phone', $admin->phone) }}" placeholder="+91 9876543210"
                        class="w-full px-3.5 py-2.5 bg-white border border-[#CBD5E1] focus:border-[#087CFE] text-xs font-semibold text-[#0F172A] outline-none transition">
                </div>

                <div>
                    <label class="block text-xs font-bold text-[#0F172A] mb-1.5">City / Base Location</label>
                    <input type="text" name="city" value="{{ old('city', $admin->city ?? 'Kolkata') }}"
                        class="w-full px-3.5 py-2.5 bg-white border border-[#CBD5E1] focus:border-[#087CFE] text-xs font-semibold text-[#0F172A] outline-none transition">
                </div>

                <div class="pt-2 flex items-center justify-between">
                    <div class="inline-flex items-center gap-1.5 px-2.5 py-1 bg-amber-50 border border-amber-200 text-amber-800 text-[10px] font-bold">
                        <i class="fa-solid fa-crown text-amber-600"></i> Role: {{ strtoupper($admin->role) }}
                    </div>

                    <button type="submit"
                        class="px-5 py-2.5 bg-[#087CFE] hover:bg-[#0066D6] text-white text-xs font-bold transition flex items-center gap-2">
                        <i class="fa-solid fa-floppy-disk"></i>
                        <span>Save Profile</span>
                    </button>
                </div>
            </form>
        </div>

        <!-- Card 2: Security & Change Password -->
        <div class="bg-white border border-[#E2E8F0] shadow-sm p-6">
            <div class="flex items-center gap-3 pb-4 mb-5 border-b border-[#E2E8F0]">
                <div class="w-10 h-10 bg-rose-50 text-rose-600 flex items-center justify-center font-bold text-base border border-rose-100">
                    <i class="fa-solid fa-lock"></i>
                </div>
                <div>
                    <h2 class="text-sm font-bold text-[#0F172A]">Password</h2>
                </div>
            </div>

            <form action="{{ route('admin.password.update') }}" method="POST" class="space-y-4">
                @csrf

                <div>
                    <label class="block text-xs font-bold text-[#0F172A] mb-1.5">Current Password</label>
                    <input type="password" name="current_password" required placeholder="Enter current admin password"
                        class="w-full px-3.5 py-2.5 bg-white border border-[#CBD5E1] focus:border-[#087CFE] text-xs font-semibold text-[#0F172A] outline-none transition">
                </div>

                <div>
                    <label class="block text-xs font-bold text-[#0F172A] mb-1.5">New Password</label>
                    <input type="password" name="password" required minlength="6" placeholder="At least 6 characters"
                        class="w-full px-3.5 py-2.5 bg-white border border-[#CBD5E1] focus:border-[#087CFE] text-xs font-semibold text-[#0F172A] outline-none transition">
                </div>

                <div>
                    <label class="block text-xs font-bold text-[#0F172A] mb-1.5">Confirm New Password</label>
                    <input type="password" name="password_confirmation" required minlength="6" placeholder="Repeat new password"
                        class="w-full px-3.5 py-2.5 bg-white border border-[#CBD5E1] focus:border-[#087CFE] text-xs font-semibold text-[#0F172A] outline-none transition">
                </div>

                <div class="pt-2 flex justify-end">
                    <button type="submit"
                        class="px-5 py-2.5 bg-[#0F172A] hover:bg-[#1E293B] text-white text-xs font-bold transition flex items-center gap-2">
                        <i class="fa-solid fa-key"></i>
                        <span>Change Password</span>
                    </button>
                </div>
            </form>
        </div>

    </div>
</div>
@endsection
