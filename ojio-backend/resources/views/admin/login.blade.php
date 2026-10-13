<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Login - OJIO Console</title>
    <link rel="icon" type="image/png" href="/assets/images/logo.png">
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['Outfit', 'sans-serif'],
                    }
                }
            }
        }
    </script>
</head>
<body class="bg-[#0B1523] min-h-screen flex items-center justify-center p-4 antialiased text-slate-100 font-sans relative overflow-hidden">

    <!-- Subtle Ambient Lighting -->
    <div class="absolute -top-40 -left-40 w-96 h-96 bg-blue-600/10 rounded-full blur-3xl pointer-events-none"></div>
    <div class="absolute -bottom-40 -right-40 w-96 h-96 bg-indigo-600/10 rounded-full blur-3xl pointer-events-none"></div>

    <div class="w-full max-w-md relative z-10">

        <!-- Logo & Header (No Background Box around Logo) -->
        <div class="text-center mb-8">
            <div class="mb-4 flex justify-center">
                <img src="/assets/images/logo.png" alt="OJIO" class="h-10 object-contain drop-shadow-sm" onerror="this.src='/assets/images/ojio_logo.png'">
            </div>
            <h1 class="text-2xl font-black tracking-tight text-white">Admin Login</h1>
        </div>

        <!-- Clean, Crisp Professional Login Card (No Rounded Bubbly Corners) -->
        <div class="rounded-xl bg-[#111C2E] border border-[#1E2E48] p-8 shadow-2xl shadow-black/60">

            {{-- Flash Messages (Only Rendered When Set - No Empty Divs) --}}
            @if(session('success'))
                <div class="mb-5 p-3.5 bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-semibold flex items-center gap-2.5">
                    <i class="fa-solid fa-circle-check"></i>
                    <span>{{ session('success') }}</span>
                </div>
            @endif

            @if(session('error') || $errors->any())
                <div class="mb-5 p-3.5 bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs font-semibold flex items-center gap-2.5">
                    <i class="fa-solid fa-triangle-exclamation"></i>
                    <span>{{ session('error') ?? $errors->first() }}</span>
                </div>
            @endif

            <form action="{{ route('admin.login.submit') }}" method="POST" class="space-y-5">
                @csrf

                <div>
                    <label class="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-2">Admin Email</label>
                    <div class="relative">
                        <span class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-500 text-sm">
                            <i class="fa-solid fa-envelope"></i>
                        </span>
                        <input type="email" name="email" value="{{ old('email') }}" required autofocus
                            placeholder="admin@ojio.com"
                            class="w-full pl-10 pr-4 py-3 bg-[#09121E] border border-[#1E2E48] focus:border-[#087CFE] focus:ring-1 focus:ring-[#087CFE] text-sm text-white placeholder-slate-500 outline-none transition">
                    </div>
                </div>

                <div>
                    <div class="flex items-center justify-between mb-2">
                        <label class="block text-xs font-bold text-slate-300 uppercase tracking-wider">Password</label>
                    </div>
                    <div class="relative">
                        <span class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-500 text-sm">
                            <i class="fa-solid fa-lock"></i>
                        </span>
                        <input type="password" id="passwordInput" name="password" required
                            placeholder="Enter admin password"
                            class="w-full pl-10 pr-11 py-3 bg-[#09121E] border border-[#1E2E48] focus:border-[#087CFE] focus:ring-1 focus:ring-[#087CFE] text-sm text-white placeholder-slate-500 outline-none transition">
                        <button type="button" id="toggleBtn" class="absolute inset-y-0 right-0 pr-3.5 flex items-center text-slate-500 hover:text-slate-300 transition text-sm">
                            <i id="eyeIcon" class="fa-solid fa-eye"></i>
                        </button>
                    </div>
                </div>

                <div class="flex items-center justify-between text-xs text-slate-400 pt-1">
                    <label class="flex items-center gap-2 cursor-pointer select-none">
                        <input type="checkbox" name="remember" class="w-4 h-4 bg-[#09121E] border-[#1E2E48] text-[#087CFE] focus:ring-0">
                        <span>Remember me</span>
                    </label>

                </div>

                <button type="submit"
                    class="w-full py-3.5 px-4 bg-[#087CFE] hover:bg-[#0066D6] text-white font-bold tracking-wide transition duration-150 flex items-center justify-center gap-2 text-sm shadow-md shadow-[#087CFE]/20">
                    <span>Sign In</span>
                    <i class="fa-solid fa-arrow-right text-xs"></i>
                </button>
            </form>
        </div>

        <div class="mt-8 text-center text-xs text-slate-500 space-y-2">
            <p><i class="fa-solid fa-shield-halved text-[#087CFE] mr-1"></i> Authorized Personnel Access Only</p>
            <p><a href="/" class="text-slate-400 hover:text-white transition font-medium">&larr; Return to Public Marketplace</a></p>
        </div>
    </div>

    <script>
        document.getElementById('toggleBtn').addEventListener('click', function() {
            var input = document.getElementById('passwordInput');
            var icon = document.getElementById('eyeIcon');
            if (input.type === 'password') {
                input.type = 'text';
                icon.classList.remove('fa-eye');
                icon.classList.add('fa-eye-slash');
            } else {
                input.type = 'password';
                icon.classList.remove('fa-eye-slash');
                icon.classList.add('fa-eye');
            }
        });
    </script>
</body>
</html>
