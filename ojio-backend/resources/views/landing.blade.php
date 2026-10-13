<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OJIO - Fast & Verified Local Classified Marketplace</title>
    <link rel="icon" type="image/png" href="/assets/images/logo.png">

    <!-- Open Graph / SEO Meta Tags -->
    <meta name="description" content="OJIO is India's fast, verified local peer-to-peer classified marketplace for Cars, Bikes, Mobiles, and Electronics with instant chat and GPS neighborhood discovery.">
    <meta property="og:title" content="OJIO - Verified Classified Marketplace">
    <meta property="og:description" content="Sell Faster. Buy Smarter. Real-time neighborhood marketplace across India.">
    <meta property="og:image" content="/assets/images/logo.png">
    <meta name="theme-color" content="#03172D">

    <!-- Google Fonts & Tailwind -->
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800;900&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">

    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        ojio: {
                            blue: '#087CFE',
                            blueHover: '#0066D6',
                            dark: '#03172D',
                            cardDark: '#08192E',
                            borderDark: '#162C46',
                            surface: '#F8FAFC',
                            textDark: '#0F172A',
                            muted: '#64748B',
                        }
                    },
                    fontFamily: {
                        sans: ['Outfit', 'Inter', 'sans-serif'],
                    }
                }
            }
        }
    </script>

    <style>
        body { font-family: 'Outfit', sans-serif; }
        .gradient-navy {
            background: linear-gradient(135deg, #020F1E 0%, #03172D 50%, #062344 100%);
        }
        .glass-nav {
            background: rgba(3, 23, 45, 0.92);
            backdrop-filter: blur(12px);
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
        }
        .no-scrollbar::-webkit-scrollbar { display: none; }
        .no-scrollbar { -ms-overflow-style: none; scrollbar-width: none; }
    </style>
</head>
<body class="gradient-navy text-slate-100 min-h-screen antialiased selection:bg-[#087CFE] selection:text-white">

    <!-- Top Announcement Bar -->
    <div class="bg-[#031527] py-2 px-4 text-center text-xs font-semibold text-white tracking-wide flex items-center justify-center gap-2 border-b border-white/10 shadow-sm">
        <span class="bg-[#087CFE]/20 text-[#38bdf8] border border-[#087CFE]/30 px-2 py-0.5 text-[10px] uppercase font-bold tracking-wider">Monetization Active</span>
        <span>Every new member gets <strong class="text-white underline decoration-blue-400">2 Free Ad Listings</strong> with full marketplace reach!</span>
    </div>

    <!-- Header / Navigation Bar -->
    <header class="sticky top-0 z-50 glass-nav">
        <div class="max-w-[1536px] mx-auto px-4 sm:px-8 lg:px-12 h-16 flex items-center justify-between">
            <!-- Brand Logo (Clean Logo Image - No background container) -->
            <a href="/" class="flex items-center">
                <img src="/assets/images/logo.png" alt="OJIO" class="h-8 object-contain" onerror="this.src='/assets/images/ojio_logo.png'">
            </a>

            <!-- Nav Links -->
            <nav class="hidden md:flex items-center gap-8 text-sm font-semibold text-slate-300">
                <a href="#categories" class="hover:text-white transition">Categories</a>
                <a href="#live-feed" class="hover:text-white transition">Live Marketplace</a>
                @if(isset($coupons) && count($coupons) > 0)
                    <a href="#offers" class="hover:text-white transition">Special Offers</a>
                @endif
                <a href="#download" class="hover:text-white transition">Get the App</a>
            </nav>

            <!-- Actions -->
            <div class="flex items-center gap-3">
                <a href="{{ route('download.apk') }}" class="flex items-center gap-2 px-5 py-2 rounded-xl bg-[#087CFE] hover:bg-[#0066D6] text-white font-bold text-xs sm:text-sm shadow-md shadow-[#087CFE]/25 transition-all duration-200">
                    <i class="fa-brands fa-android text-base"></i>
                    <span>Download APK</span>
                </a>
            </div>
        </div>
    </header>

    <!-- Hero Section with Realistic Modern Smartphone Frame -->
    <section class="relative overflow-hidden pt-6 pb-12 lg:pt-10 lg:pb-16">
        <div class="max-w-[1536px] mx-auto px-4 sm:px-8 lg:px-12 grid lg:grid-cols-12 gap-12 items-center">

            <!-- Left Hero Content -->
            <div class="lg:col-span-7 text-center lg:text-left space-y-8">
                <div class="inline-flex items-center gap-2 px-3 py-1.5 bg-white/5 border border-white/10 text-xs font-semibold text-slate-300">
                    <span class="flex h-2 w-2 relative">
                        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                        <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                    </span>
                    <span>Verified peer-to-peer marketplace across Indian cities</span>
                </div>

                <h1 class="text-4xl sm:text-5xl lg:text-6xl font-black tracking-tight text-white leading-[1.15]">
                    Sell Faster. Buy Smarter. <br>
                    <span class="bg-gradient-to-r from-[#087CFE] via-blue-300 to-emerald-400 bg-clip-text text-transparent">Right in Your Neighborhood.</span>
                </h1>

                <p class="text-base sm:text-lg text-slate-300 max-w-2xl mx-auto lg:mx-0 font-normal leading-relaxed">
                    OJIO is India's next-generation classified marketplace engineered for peer-to-peer buying and selling across <strong>Vehicles (2/3/4 Wheelers)</strong>, <strong>Mobiles</strong>, and <strong>Electronics</strong> with GPS proximity discovery, verified seller profiles, and direct buyer-seller calls.
                </p>

                <!-- CTA Download Buttons -->
                <div id="download" class="pt-2 flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
                    <!-- Direct APK Download -->
                    <a href="{{ route('download.apk') }}" class="flex items-center gap-4 px-6 py-3.5 rounded-2xl bg-gradient-to-r from-[#087CFE] to-[#0066D6] hover:from-[#0066D6] hover:to-[#087CFE] text-white font-bold text-base shadow-xl shadow-[#087CFE]/30 hover:shadow-[#087CFE]/50 border border-blue-400/30 transition-all duration-300 transform hover:-translate-y-0.5">
                        <i class="fa-brands fa-android text-3xl"></i>
                        <div class="text-left">
                            <div class="text-[10px] font-semibold uppercase tracking-wider text-blue-100">Direct Download</div>
                            <div class="text-sm font-extrabold">Download Android APK (v1.0)</div>
                        </div>
                    </a>

                    <!-- Google Play Store Redirect -->
                    <a href="https://play.google.com/store/apps" target="_blank" class="flex items-center gap-4 px-6 py-3.5 rounded-2xl bg-white/[0.06] hover:bg-white/[0.12] border border-white/15 hover:border-emerald-400/40 text-white font-bold text-base backdrop-blur-md transition-all duration-300 transform hover:-translate-y-0.5">
                        <i class="fa-brands fa-google-play text-3xl text-emerald-400"></i>
                        <div class="text-left">
                            <div class="text-[10px] font-semibold uppercase tracking-wider text-slate-300">Official Store</div>
                            <div class="text-sm font-extrabold">Get on Google Play</div>
                        </div>
                    </a>
                </div>

                <!-- Trust Badges (Clean Transparent Layout - No Rigid Rectangle Boxes) -->
                <div class="pt-6 grid grid-cols-3 gap-4 border-t border-white/10 max-w-lg mx-auto lg:mx-0 text-center lg:text-left">
                    <div class="space-y-1">
                        <div class="text-xl sm:text-2xl font-black text-white tracking-tight whitespace-nowrap">2 Free Ads</div>
                        <div class="text-[10px] sm:text-xs text-slate-400 font-medium">For every user</div>
                    </div>
                    <div class="space-y-1">
                        <div class="text-xl sm:text-2xl font-black text-emerald-400 tracking-tight whitespace-nowrap">GPS Radius</div>
                        <div class="text-[10px] sm:text-xs text-slate-400 font-medium">Locality discovery</div>
                    </div>
                    <div class="space-y-1">
                        <div class="text-xl sm:text-2xl font-black text-[#087CFE] tracking-tight whitespace-nowrap">Direct Chat</div>
                        <div class="text-[10px] sm:text-xs text-slate-400 font-medium">Buyer-seller connect</div>
                    </div>
                </div>
            </div>

            <!-- Right: Actual Smartphone Proportions & Realistic App Showcase -->
            <div class="lg:col-span-5 flex justify-center items-center">
                <div class="relative w-[340px] sm:w-[360px]">
                    <!-- Outer Smartphone Chassis -->
                    <div class="relative rounded-[48px] p-3 bg-gradient-to-b from-[#1E293B] via-[#0F172A] to-[#0A0F1D] border-4 border-[#334155]/60 shadow-[0_25px_60px_-15px_rgba(0,0,0,0.9),0_0_50px_rgba(8,124,254,0.2)] ring-1 ring-white/10">

                        <!-- Side Hardware Buttons -->
                        <div class="absolute -left-[7px] top-28 w-[3px] h-8 bg-slate-600 rounded-l"></div>
                        <div class="absolute -left-[7px] top-40 w-[3px] h-12 bg-slate-600 rounded-l"></div>
                        <div class="absolute -left-[7px] top-56 w-[3px] h-12 bg-slate-600 rounded-l"></div>
                        <div class="absolute -right-[7px] top-36 w-[3px] h-16 bg-slate-600 rounded-r"></div>

                        <!-- Phone Screen -->
                        <div class="relative rounded-[38px] overflow-hidden bg-[#F8FAFC] text-[#0F172A] h-[640px] flex flex-col justify-between select-none border border-black/40">

                            <!-- Phone Status Bar & Dynamic Island Notch -->
                            <div class="bg-[#03172D] text-white pt-2 pb-1.5 px-6 flex items-center justify-between text-[11px] font-semibold tracking-wider relative z-30">
                                <span>9:41</span>
                                <!-- Dynamic Island Pill -->
                                <div class="w-20 h-4 bg-black rounded-full flex items-center justify-end px-2">
                                    <div class="w-2 h-2 rounded-full bg-slate-900 border border-slate-700"></div>
                                </div>
                                <div class="flex items-center gap-1.5 text-[10px]">
                                    <i class="fa-solid fa-signal"></i>
                                    <i class="fa-solid fa-wifi"></i>
                                    <i class="fa-solid fa-battery-full text-xs text-emerald-400"></i>
                                </div>
                            </div>

                            <!-- Mobile App Header: logo and location, search and wallet -->
                            <div class="bg-[#03172D] text-white px-4 py-2.5 flex items-center justify-between border-b border-white/10 relative z-20">
                                <div class="flex items-center gap-2">
                                    <img src="/assets/images/logo.png" alt="OJIO" class="h-6 object-contain" onerror="this.src='/assets/images/ojio_logo.png'">
                                    <div class="flex items-center gap-1 text-[11px] text-blue-200 bg-white/10 px-2 py-0.5">
                                        <i class="fa-solid fa-location-dot text-emerald-400 text-[10px]"></i>
                                        <span class="font-bold">Kolkata, WB</span>
                                    </div>
                                </div>
                                <div class="flex items-center gap-2 text-slate-300">
                                    <div class="w-7 h-7 bg-white/10 flex items-center justify-center text-xs">
                                        <i class="fa-solid fa-magnifying-glass"></i>
                                    </div>
                                    <div class="w-7 h-7 bg-white/10 flex items-center justify-center text-xs text-[#087CFE]">
                                        <i class="fa-solid fa-wallet"></i>
                                    </div>
                                </div>
                            </div>

                            <!-- Phone Scrollable Feed Content -->
                            <div class="flex-1 overflow-y-auto no-scrollbar p-3 space-y-3 bg-[#F1F5F9]">

                                <!-- Active Promo / Monetization Banner -->
                                <div class="bg-gradient-to-r from-[#03172D] to-[#0A3366] text-white p-3 border border-blue-400/20 shadow-sm flex items-center justify-between">
                                    <div class="space-y-0.5">
                                        <span class="text-[9px] font-bold text-amber-300 uppercase tracking-widest block">SPECIAL PROMOTION</span>
                                        <div class="text-xs font-black">Sell in 48 Hours with Featured Ad</div>
                                        <div class="text-[9px] text-slate-300">Boost listing to top of city feed</div>
                                    </div>
                                    <span class="px-2.5 py-1 bg-[#087CFE] text-white font-bold text-[9px] uppercase tracking-wider">
                                        BOOST
                                    </span>
                                </div>

                                <!-- Categories Row -->
                                <div>
                                    <div class="text-[10px] font-extrabold uppercase tracking-wider text-slate-500 mb-2">Browse Categories</div>
                                    <div class="grid grid-cols-4 gap-2 text-center">
                                        <div class="bg-white p-2 border border-slate-200 shadow-sm flex flex-col items-center justify-center">
                                            <img src="/assets/images/cat_cars.png" class="h-6 w-6 object-contain" alt="Cars" onerror="this.src='/assets/images/logo.png'">
                                            <span class="text-[9px] font-bold text-slate-800 mt-1">Cars</span>
                                        </div>
                                        <div class="bg-white p-2 border border-slate-200 shadow-sm flex flex-col items-center justify-center">
                                            <img src="/assets/images/cat_bikes.png" class="h-6 w-6 object-contain" alt="Bikes" onerror="this.src='/assets/images/logo.png'">
                                            <span class="text-[9px] font-bold text-slate-800 mt-1">Bikes</span>
                                        </div>
                                        <div class="bg-white p-2 border border-slate-200 shadow-sm flex flex-col items-center justify-center">
                                            <img src="/assets/images/cat_mobiles.png" class="h-6 w-6 object-contain" alt="Mobiles" onerror="this.src='/assets/images/logo.png'">
                                            <span class="text-[9px] font-bold text-slate-800 mt-1">Mobiles</span>
                                        </div>
                                        <div class="bg-white p-2 border border-slate-200 shadow-sm flex flex-col items-center justify-center">
                                            <img src="/assets/images/cat_electronics.png" class="h-6 w-6 object-contain" alt="Electronics" onerror="this.src='/assets/images/logo.png'">
                                            <span class="text-[9px] font-bold text-slate-800 mt-1">Laptops</span>
                                        </div>
                                    </div>
                                </div>

                                <!-- Recommended Listings in Mobile Screen -->
                                <div>
                                    <div class="flex items-center justify-between mb-2">
                                        <span class="text-[11px] font-black text-[#071A2F]">Fresh Recommendations</span>
                                        <span class="text-[10px] text-[#64748B]">Kolkata & Nearby</span>
                                    </div>
                                    <div class="grid grid-cols-2 gap-2.5">
                                        <!-- Card 1 -->
                                        <div class="bg-white border border-[#E2E8F0] shadow-sm flex flex-col justify-between">
                                            <div class="relative">
                                                <img src="https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=400&auto=format&fit=crop&q=80" class="w-full h-20 object-cover">
                                                <span class="absolute top-1 left-1 px-1.5 py-0.5 bg-[#087CFE] text-white font-black text-[8px] uppercase tracking-wider">
                                                    FEATURED
                                                </span>
                                            </div>
                                            <div class="p-2 space-y-0.5">
                                                <div class="text-xs font-black text-[#087CFE]">&#8377; 13,50,000</div>
                                                <div class="text-[10px] font-bold text-[#071A2F] truncate">Hyundai Creta SX 2021</div>
                                                <div class="text-[9px] text-[#64748B] flex items-center justify-between pt-0.5">
                                                    <span>Salt Lake, Kolkata</span>
                                                    <i class="fa-solid fa-circle-check text-emerald-500 text-[9px]"></i>
                                                </div>
                                            </div>
                                        </div>

                                        <!-- Card 2 -->
                                        <div class="bg-white border border-[#E2E8F0] shadow-sm flex flex-col justify-between">
                                            <div class="relative">
                                                <img src="https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400&auto=format&fit=crop&q=80" class="w-full h-20 object-cover">
                                                <span class="absolute top-1 left-1 px-1.5 py-0.5 bg-black/60 text-white font-black text-[8px] uppercase tracking-wider">
                                                    MOBILES
                                                </span>
                                            </div>
                                            <div class="p-2 space-y-0.5">
                                                <div class="text-xs font-black text-[#087CFE]">&#8377; 73,000</div>
                                                <div class="text-[10px] font-bold text-[#071A2F] truncate">iPhone 13 128GB</div>
                                                <div class="text-[9px] text-[#64748B] flex items-center justify-between pt-0.5">
                                                    <span>New Town, Kolkata</span>
                                                    <i class="fa-solid fa-circle-check text-emerald-500 text-[9px]"></i>
                                                </div>
                                            </div>
                                        </div>

                                        <!-- Card 3 -->
                                        <div class="bg-white border border-[#E2E8F0] shadow-sm flex flex-col justify-between">
                                            <div class="relative">
                                                <img src="https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=400&auto=format&fit=crop&q=80" class="w-full h-20 object-cover">
                                                <span class="absolute top-1 left-1 px-1.5 py-0.5 bg-[#03172D]/70 text-white font-black text-[8px] uppercase tracking-wider">
                                                    BIKES
                                                </span>
                                            </div>
                                            <div class="p-2 space-y-0.5">
                                                <div class="text-xs font-black text-[#087CFE]">&#8377; 1,45,000</div>
                                                <div class="text-[10px] font-bold text-[#071A2F] truncate">Royal Enfield 350</div>
                                                <div class="text-[9px] text-[#64748B] flex items-center justify-between pt-0.5">
                                                    <span>Park Street, Kolkata</span>
                                                    <i class="fa-solid fa-circle-check text-emerald-500 text-[9px]"></i>
                                                </div>
                                            </div>
                                        </div>

                                        <!-- Card 4 -->
                                        <div class="bg-white border border-[#E2E8F0] shadow-sm flex flex-col justify-between">
                                            <div class="relative">
                                                <img src="https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400&auto=format&fit=crop&q=80" class="w-full h-20 object-cover">
                                                <span class="absolute top-1 left-1 px-1.5 py-0.5 bg-[#03172D]/70 text-white font-black text-[8px] uppercase tracking-wider">
                                                    LAPTOPS
                                                </span>
                                            </div>
                                            <div class="p-2 space-y-0.5">
                                                <div class="text-xs font-black text-[#087CFE]">&#8377; 62,000</div>
                                                <div class="text-[10px] font-bold text-[#071A2F] truncate">MacBook Air M1</div>
                                                <div class="text-[9px] text-[#64748B] flex items-center justify-between pt-0.5">
                                                    <span>Howrah, Kolkata</span>
                                                    <i class="fa-solid fa-circle-check text-emerald-500 text-[9px]"></i>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                            </div>

                            <!-- Real Bottom Navigation Bar (Matches Flutter App) -->
                            <div class="bg-white border-t border-[#E2E8F0] px-4 py-2 flex items-center justify-between text-[#64748B] relative z-20 shadow-md">
                                <div class="flex flex-col items-center text-[#087CFE]">
                                    <i class="fa-solid fa-house text-sm"></i>
                                    <span class="text-[9px] font-bold mt-0.5">Home</span>
                                </div>
                                <div class="flex flex-col items-center hover:text-slate-900 transition">
                                    <i class="fa-regular fa-comment-dots text-sm"></i>
                                    <span class="text-[9px] font-bold mt-0.5">Chats</span>
                                </div>

                                <!-- Sell Floating Action Button -->
                                <div class="-mt-6 flex flex-col items-center">
                                    <div class="w-11 h-11 bg-[#087CFE] text-white flex items-center justify-center shadow-lg border-2 border-white">
                                        <i class="fa-solid fa-plus text-base font-black"></i>
                                    </div>
                                    <span class="text-[9px] font-black text-[#087CFE] mt-0.5 uppercase tracking-wide">SELL</span>
                                </div>

                                <div class="flex flex-col items-center hover:text-slate-900 transition">
                                    <i class="fa-regular fa-heart text-sm"></i>
                                    <span class="text-[9px] font-bold mt-0.5">My Ads</span>
                                </div>
                                <div class="flex flex-col items-center hover:text-slate-900 transition">
                                    <i class="fa-regular fa-user text-sm"></i>
                                    <span class="text-[9px] font-bold mt-0.5">Account</span>
                                </div>
                            </div>

                            <!-- iOS Home Indicator -->
                            <div class="bg-white pb-2 flex justify-center">
                                <div class="w-28 h-1 bg-slate-300 rounded-full"></div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

        </div>
    </section>

    <!-- Active Limited-Time Offers & Coupons Banner -->
    @if(isset($coupons) && count($coupons) > 0)
    <section id="offers" class="py-12 bg-[#021122] border-y border-[#087CFE]/30 relative overflow-hidden">
        <div class="max-w-[1536px] mx-auto px-4 sm:px-8 lg:px-12 relative z-10">
            <div class="flex flex-col md:flex-row items-center justify-between gap-6">
                <div class="max-w-xl text-center md:text-left">
                    <div class="inline-flex items-center space-x-2 px-3 py-1 bg-[#087CFE]/20 border border-[#087CFE]/40 text-[#38bdf8] text-xs font-bold uppercase tracking-wider mb-2">
                        <span>Limited Time Promo Offers</span>
                    </div>
                    <h2 class="text-2xl sm:text-3xl font-black text-white">Special Deals & Promo Discounts</h2>
                    <p class="text-slate-300 text-xs sm:text-sm mt-1">Apply promo codes inside the OJIO mobile app during ad submission to unlock instant featured badges & top search visibility.</p>
                </div>

                <div class="grid sm:grid-cols-2 gap-4 w-full md:w-auto">
                    @foreach($coupons as $coupon)
                    <div class="p-4 bg-white/5 border border-white/15 flex flex-col justify-between hover:border-[#087CFE] transition">
                        <div>
                            <div class="flex items-center justify-between gap-3 mb-2">
                                <span class="px-3 py-1 bg-[#087CFE] text-white font-mono font-bold text-xs uppercase tracking-wider">
                                    {{ $coupon->code }}
                                </span>
                                <span class="text-xs font-bold text-amber-400">
                                    {{ $coupon->type === 'percentage' ? $coupon->value . '% OFF' : '&#8377; ' . number_format($coupon->value, 0) . ' FLAT OFF' }}
                                </span>
                            </div>
                            <p class="text-xs text-slate-200 font-medium line-clamp-2">{{ $coupon->description }}</p>
                        </div>
                        <div class="mt-3 pt-2 border-t border-white/10 flex items-center justify-between text-[11px] text-slate-400">
                            <span>Redeem in OJIO App</span>
                            <span class="text-emerald-400 font-semibold">Active Now</span>
                        </div>
                    </div>
                    @endforeach
                </div>
            </div>
        </div>
    </section>
    @endif

    <!-- Client Categories Section (4 Core OJIO Categories) -->
    <section id="categories" class="py-20 bg-[#04162B] border-y border-white/10">
        <div class="max-w-[1536px] mx-auto px-4 sm:px-8 lg:px-12">
            <div class="text-center max-w-2xl mx-auto mb-14">
                <span class="text-xs font-extrabold uppercase tracking-widest text-[#087CFE]">Verified Marketplace</span>
                <h2 class="text-3xl sm:text-4xl font-black text-white mt-2">Focused on What Sells Fast</h2>
                <p class="text-slate-300 text-sm mt-2">Specialized categories optimized with custom filters: vehicle make/model, fuel type, km driven, and device specs.</p>
            </div>

            <div class="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
                <!-- Cars -->
                <div class="p-6 rounded-2xl bg-white/[0.03] hover:bg-white/[0.07] border border-white/10 hover:border-[#087CFE]/50 transition-all duration-300 text-center group hover:-translate-y-1">
                    <div class="h-20 flex items-center justify-center mb-3">
                        <img src="/assets/images/cat_cars.png" class="max-h-16 w-auto object-contain drop-shadow-md group-hover:scale-110 transition-transform duration-300" alt="Cars">
                    </div>
                    <h3 class="font-bold text-white text-base">Cars (4 Wheelers)</h3>
                    <p class="text-xs text-slate-400 mt-1 leading-relaxed">Sedans, SUVs, hatchbacks & verified single-owner cars.</p>
                </div>

                <!-- Bikes -->
                <div class="p-6 rounded-2xl bg-white/[0.03] hover:bg-white/[0.07] border border-white/10 hover:border-[#087CFE]/50 transition-all duration-300 text-center group hover:-translate-y-1">
                    <div class="h-20 flex items-center justify-center mb-3">
                        <img src="/assets/images/cat_bikes.png" class="max-h-16 w-auto object-contain drop-shadow-md group-hover:scale-110 transition-transform duration-300" alt="Bikes">
                    </div>
                    <h3 class="font-bold text-white text-base">Bikes (2 Wheelers)</h3>
                    <p class="text-xs text-slate-400 mt-1 leading-relaxed">Royal Enfield, cruisers, commuter bikes & scooters.</p>
                </div>

                <!-- Mobiles -->
                <div class="p-6 rounded-2xl bg-white/[0.03] hover:bg-white/[0.07] border border-white/10 hover:border-[#087CFE]/50 transition-all duration-300 text-center group hover:-translate-y-1">
                    <div class="h-20 flex items-center justify-center mb-3">
                        <img src="/assets/images/cat_mobiles.png" class="max-h-16 w-auto object-contain drop-shadow-md group-hover:scale-110 transition-transform duration-300" alt="Mobiles">
                    </div>
                    <h3 class="font-bold text-white text-base">Mobiles</h3>
                    <p class="text-xs text-slate-400 mt-1 leading-relaxed">Apple iPhones, Samsung Galaxy & 5G smartphones.</p>
                </div>

                <!-- Electronics / Laptop -->
                <div class="p-6 rounded-2xl bg-white/[0.03] hover:bg-white/[0.07] border border-white/10 hover:border-[#087CFE]/50 transition-all duration-300 text-center group hover:-translate-y-1">
                    <div class="h-20 flex items-center justify-center mb-3">
                        <img src="/assets/images/cat_electronics.png" class="max-h-16 w-auto object-contain drop-shadow-md group-hover:scale-110 transition-transform duration-300" alt="Electronics">
                    </div>
                    <h3 class="font-bold text-white text-base">Electronics</h3>
                    <p class="text-xs text-slate-400 mt-1 leading-relaxed">MacBooks, laptops, 4K OLED TVs & gaming gadgets.</p>
                </div>
            </div>
        </div>
    </section>

    <!-- Live Marketplace Showcase -->
    <section id="live-feed" class="py-20">
        <div class="max-w-[1536px] mx-auto px-4 sm:px-8 lg:px-12">
            <div class="flex flex-col sm:flex-row sm:items-end justify-between mb-12">
                <div>
                    <span class="text-xs font-extrabold uppercase tracking-widest text-[#087CFE]">Live Marketplace</span>
                    <h2 class="text-3xl font-black text-white mt-1">Fresh Recommendations in India</h2>
                </div>
                <a href="{{ route('download.apk') }}" class="text-sm font-bold text-[#087CFE] hover:text-blue-300 mt-2 sm:mt-0 flex items-center gap-1.5">
                    <span>View all listings on Mobile App</span>
                    <i class="fa-solid fa-arrow-right"></i>
                </a>
            </div>

            <!-- Professional Cards Grid (Clean Borders, No Bubbly Corners) -->
            <div class="grid sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                @php
                    $demoAds = $featuredListings->map(fn ($listing) => (object) [
                        'title' => $listing->title,
                        'price' => $listing->price,
                        'category_name' => $listing->category?->name ?? 'Marketplace',
                        'locality' => $listing->locality,
                        'city' => $listing->city,
                        'image' => $listing->images->first()?->image_path ?? asset('assets/images/logo.png'),
                        'is_featured' => $listing->is_featured,
                    ]);
                @endphp

                @foreach($demoAds as $ad)
                    <div class="bg-white text-[#071A2F] border border-[#E2E8F0] shadow-sm hover:shadow-md transition group flex flex-col justify-between">
                        <div class="relative overflow-hidden">
                            <img src="{{ $ad->image }}" class="w-full h-48 object-cover group-hover:scale-105 transition duration-300">
                            <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent"></div>

                            @if($ad->is_featured)
                                <span class="absolute top-3 left-3 px-2.5 py-1 bg-[#087CFE] text-white font-black text-[10px] tracking-wider uppercase shadow-md flex items-center gap-1">
                                    <i class="fa-solid fa-bolt text-xs"></i> FEATURED
                                </span>
                            @endif

                            <span class="absolute bottom-2.5 left-3 px-2 py-0.5 bg-black/70 text-white font-extrabold text-[9px] uppercase tracking-wider">
                                {{ $ad->category_name }}
                            </span>
                        </div>
                        <div class="p-4 space-y-2">
                            <div class="text-xl font-black text-[#087CFE]">
                                &#8377; {{ number_format($ad->price) }}
                            </div>
                            <h4 class="font-bold text-sm text-[#071A2F] truncate">{{ $ad->title }}</h4>
                            <div class="text-xs text-[#64748B] flex items-center justify-between pt-1 border-t border-[#E2E8F0]">
                                <span class="flex items-center gap-1">
                                    <i class="fa-solid fa-location-dot text-[#94A3B8]"></i>
                                    {{ $ad->locality ? $ad->locality . ', ' : '' }}{{ $ad->city }}
                                </span>
                                <span class="text-emerald-600 font-bold flex items-center gap-1 text-[11px]">
                                    <i class="fa-solid fa-arrow-right"></i> In the app
                                </span>
                            </div>
                        </div>
                    </div>
                @endforeach
            </div>
        </div>
    </section>

    <!-- Footer CTA -->
    <footer class="bg-[#020F1D] border-t border-white/10 py-16">
        <div class="max-w-[1536px] mx-auto px-4 sm:px-8 lg:px-12 text-center space-y-6">
            <a href="/" class="inline-block">
                <img src="/assets/images/logo.png" alt="OJIO" class="h-9 mx-auto object-contain" onerror="this.src='/assets/images/ojio_logo.png'">
            </a>
            <h3 class="text-2xl font-black text-white">Start Buying & Selling on OJIO Today</h3>
            <p class="text-sm text-slate-400 max-w-md mx-auto">First 2 ads are completely free for every member. Download the official Android APK directly.</p>
            <div class="pt-2 flex justify-center gap-4">
                <a href="{{ route('download.apk') }}" class="px-7 py-3.5 rounded-2xl bg-[#087CFE] hover:bg-[#0066D6] text-white font-bold text-sm shadow-lg shadow-[#087CFE]/30 transition-all duration-300 transform hover:-translate-y-0.5 inline-flex items-center gap-2">
                    <i class="fa-brands fa-android mr-2"></i> Download APK Now
                </a>
            </div>
            <div class="pt-8 text-xs text-slate-500 border-t border-white/10">
                &copy; {{ date('Y') }} OJIO Classified Marketplace. All rights reserved.
            </div>
        </div>
    </footer>

</body>
</html>
