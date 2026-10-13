<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OJIO - Admin Dashboard</title>
    <link rel="icon" type="image/png" href="/assets/images/logo.png">
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        admin: {
                            sidebar: '#0B1523',
                            sidebarBorder: '#1A293E',
                            accent: '#087CFE',
                            accentHover: '#0066D6',
                            bg: '#F8FAFC',
                            card: '#FFFFFF',
                            border: '#E2E8F0',
                            text: '#0F172A',
                            muted: '#64748B',
                        }
                    },
                    fontFamily: {
                        sans: ['Inter', 'sans-serif'],
                    }
                }
            }
        }
    </script>
    <style>
        body { font-family: 'Inter', sans-serif; }
        main { min-width: 0; }
        nav a, header a, button { border-radius: 8px; }
        main > div > .bg-white, main section { border-radius: 12px; }
        input, select, textarea { border-radius: 8px; min-height: 38px; }
        input[type=checkbox] { min-height: auto; }
        input:focus-visible, select:focus-visible, textarea:focus-visible, button:focus-visible, a:focus-visible { outline: 2px solid #087CFE; outline-offset: 2px; }
        main .bg-white:has(> table) { overflow-x: auto; }
        table { min-width: 640px; }
        main .flex.items-center.justify-between { flex-wrap: wrap; gap: 12px; }
        #admin-sidebar { overflow-y: auto; transition: transform .2s ease; }
        @media (max-width: 1023px) {
            #admin-sidebar { transform: translateX(-100%); }
            #admin-sidebar.is-open { transform: translateX(0); }
            #admin-content { margin-left: 0; }
            #admin-content header { padding: 0 16px; gap: 8px; }
            #admin-content main { padding: 20px 16px; }
        }
        @media (max-width: 639px) {
            #admin-content header .admin-secondary { display: none; }
            main form.flex { flex-wrap: wrap; }
            main .fixed { padding: 16px; }
        }
        [id$="modal"] > div { max-height: 90dvh; overflow-y: auto; border-radius: 12px; }
    </style>
</head>
<body class="bg-[#F8FAFC] text-[#0F172A] antialiased">

    <!-- Fixed Left Sidebar -->
    <button id="sidebar-overlay" aria-label="Close navigation" class="hidden fixed inset-0 bg-black/40 z-20 lg:hidden" onclick="toggleAdminMenu(false)"></button>
    <aside id="admin-sidebar" class="fixed inset-y-0 left-0 w-64 bg-[#0B1523] border-r border-[#1A293E] flex flex-col justify-between z-30 select-none">
        <div>
            <!-- Clean Logo Header (No background box around logo) -->
            <div class="h-16 flex items-center px-6 border-b border-[#1A293E]">
                <a href="/admin" class="flex items-center gap-2.5">
                    <img src="/assets/images/logo.png" alt="OJIO" class="h-8 object-contain" onerror="this.src='/assets/images/ojio_logo.png'">
                </a>
            </div>

            <!-- Main Navigation -->
            <nav class="p-3 space-y-1 text-xs font-semibold">
                <a href="/admin" class="flex items-center gap-3 px-3 py-2.5 transition {{ request()->is('admin') ? 'bg-[#087CFE] text-white font-bold' : 'text-slate-400 hover:text-white hover:bg-white/5' }}">
                    <i class="fa-solid fa-chart-pie w-4 text-center"></i>
                    <span>Overview</span>
                </a>
                <a href="/admin/listings" class="flex items-center gap-3 px-3 py-2.5 transition {{ request()->is('admin/listings*') ? 'bg-[#087CFE] text-white font-bold' : 'text-slate-400 hover:text-white hover:bg-white/5' }}">
                    <i class="fa-solid fa-layer-group w-4 text-center"></i>
                    <span>Listings</span>
                </a>
                <a href="/admin/users" class="flex items-center gap-3 px-3 py-2.5 transition {{ request()->is('admin/users*') ? 'bg-[#087CFE] text-white font-bold' : 'text-slate-400 hover:text-white hover:bg-white/5' }}">
                    <i class="fa-solid fa-users w-4 text-center"></i>
                    <span>Users</span>
                </a>
                <a href="/admin/coupons" class="flex items-center gap-3 px-3 py-2.5 transition {{ request()->is('admin/coupons*') ? 'bg-[#087CFE] text-white font-bold' : 'text-slate-400 hover:text-white hover:bg-white/5' }}">
                    <i class="fa-solid fa-ticket w-4 text-center"></i>
                    <span>Coupons</span>
                </a>

                <a href="/admin/monetization" class="flex items-center gap-3 px-3 py-2.5 transition {{ request()->is('admin/monetization*') ? 'bg-[#087CFE] text-white font-bold' : 'text-slate-400 hover:text-white hover:bg-white/5' }}">
                    <i class="fa-solid fa-receipt w-4 text-center"></i>
                    <span>Payments & Packages</span>
                </a>
                <a href="/admin/profile" class="flex items-center gap-3 px-3 py-2.5 transition {{ request()->is('admin/profile') ? 'bg-[#087CFE] text-white font-bold' : 'text-slate-400 hover:text-white hover:bg-white/5' }}">
                    <i class="fa-solid fa-user-shield w-4 text-center"></i>
                    <span>Settings</span>
                </a>
                <a href="{{ route('admin.legal') }}" class="flex items-center gap-3 px-3 py-2.5 transition {{ request()->is('admin/legal*') ? 'bg-[#087CFE] text-white font-bold' : 'text-slate-400 hover:text-white hover:bg-white/5' }}">
                    <i class="fa-solid fa-file-contract w-4 text-center"></i>
                    <span>Legal Pages</span>
                </a>

                <!-- External Client Channels Section -->
                <div class="pt-4 mt-4 border-t border-[#1A293E]">
                    <a href="/" target="_blank" class="flex items-center gap-3 px-3 py-2 text-slate-300 hover:text-white hover:bg-white/5 transition mt-1.5">
                        <i class="fa-solid fa-arrow-up-right-from-square w-4 text-center text-[#087CFE]"></i>
                        <span>View Website</span>
                    </a>
                </div>
            </nav>
        </div>

        <!-- Sidebar Footer Status -->
        <div class="p-4 border-t border-[#1A293E] text-[11px] text-slate-400">
            <div class="flex items-center gap-2 font-semibold text-slate-200">
                <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
                <span>{{ Auth::user()->name ?? 'OJIO Admin' }}</span>
            </div>
            <div class="text-[10px] text-slate-500 mt-0.5 truncate">{{ Auth::user()->email ?? 'admin@ojio.com' }}</div>
        </div>
    </aside>

    <!-- Main Content Panel (ml-64 ensures zero overlap with sidebar) -->
    <div id="admin-content" class="ml-64 flex flex-col min-h-screen bg-[#F8FAFC]">
        <!-- Top App Bar -->
        <header class="h-16 border-b border-[#E2E8F0] bg-white px-8 flex items-center justify-between sticky top-0 z-20">
            <div class="flex items-center gap-3">
                <button type="button" class="lg:hidden p-2" aria-label="Open navigation" aria-controls="admin-sidebar" aria-expanded="false" id="menu-toggle" onclick="toggleAdminMenu()"><i class="fa-solid fa-bars"></i></button>
                <span class="text-sm font-bold text-[#0F172A] tracking-tight">OJIO Admin</span>
            </div>
            <div class="flex items-center gap-3 text-xs font-semibold">
                <a href="/" target="_blank" rel="noopener" class="admin-secondary px-3 py-1.5 bg-[#087CFE]/10 text-[#087CFE] border border-[#087CFE]/20 hover:bg-[#087CFE] hover:text-white transition flex items-center gap-1.5">
                    <i class="fa-solid fa-globe"></i> View Site
                </a>
                
                <a href="/admin/profile" class="flex items-center gap-2 px-3 py-1.5 border border-[#E2E8F0] hover:border-[#087CFE] hover:text-[#087CFE] transition text-[#0F172A]">
                    <i class="fa-solid fa-user-shield text-[#087CFE]"></i>
                    <span class="admin-secondary">{{ Auth::user()->name ?? 'Administrator' }}</span>
                </a>

                <form action="{{ route('admin.logout') }}" method="POST" class="inline m-0">
                    @csrf
                    <button type="submit" class="px-3 py-1.5 bg-rose-50 hover:bg-rose-600 hover:text-white text-rose-600 border border-rose-200 transition flex items-center gap-1.5">
                        <i class="fa-solid fa-arrow-right-from-bracket"></i>
                        <span>Logout</span>
                    </button>
                </form>
            </div>
        </header>

        <!-- Body View Area -->
        <main class="p-8 flex-1">
            @if(session('success'))
                <div data-admin-notice role="status" class="mb-6 p-4 bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-semibold flex items-center gap-2.5">
                    <i class="fa-solid fa-circle-check text-emerald-600"></i>
                    <span>{{ session('success') }}</span>
                </div>
            @endif

            @if(session('error') || $errors->any())
                <div data-admin-notice role="alert" class="mb-6 p-4 bg-rose-50 border border-rose-200 text-rose-800 text-xs font-semibold flex items-center gap-2.5">
                    <i class="fa-solid fa-triangle-exclamation text-rose-600"></i>
                    <span>{{ session('error') ?? $errors->first() }}</span>
                </div>
            @endif

            @yield('content')
        </main>
    </div>

<script>
    function dismissAdminNotices() {
        document.querySelectorAll('[data-admin-notice]').forEach(notice => notice.remove());
    }
    setTimeout(dismissAdminNotices, 3000);
    window.addEventListener('pagehide', dismissAdminNotices);
    document.addEventListener('click', (event) => {
        const link = event.target.closest('a[href]');
        if (link && link.target !== '_blank' && !link.getAttribute('href').startsWith('#')) {
            dismissAdminNotices();
        }
    });
    document.addEventListener('submit', dismissAdminNotices);
    function toggleAdminMenu(open) {
        const sidebar = document.getElementById('admin-sidebar');
        const expanded = open ?? !sidebar.classList.contains('is-open');
        sidebar.classList.toggle('is-open', expanded);
        document.getElementById('sidebar-overlay').classList.toggle('hidden', !expanded);
        document.getElementById('menu-toggle').setAttribute('aria-expanded', String(expanded));
    }
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') {
            toggleAdminMenu(false);
            document.querySelectorAll('[id$="modal"]').forEach(modal => modal.classList.add('hidden'));
        }
    });
</script>
</body>
</html>
