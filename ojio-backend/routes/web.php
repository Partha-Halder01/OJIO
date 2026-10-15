<?php

use App\Http\Controllers\Admin\AdminDashboardController;
use App\Http\Controllers\Admin\LegalDocumentController;
use App\Models\Banner;
use App\Models\Category;
use App\Models\Coupon;
use App\Models\Listing;
use App\Support\PublicFilePath;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;

// Fallback route to serve storage files if symlink is broken
Route::get('/storage/{folder}/{filename}', function ($folder, $filename) {
    $path = PublicFilePath::resolve(Storage::disk('public')->path(''), $folder.'/'.$filename);
    abort_if($path === null, 404);

    return response()->file($path, ['X-Content-Type-Options' => 'nosniff']);
})->where('filename', '.*');

// 1. App Download & Showcase Landing Page
Route::get('/', function () {
    $featuredListings = Listing::with(['images', 'category'])
        ->where('status', 'active')
        ->latest()
        ->take(8)
        ->get();

    $categories = Category::whereNull('parent_id')
        ->available()
        ->withCount('listings')
        ->with(['subcategories' => fn ($query) => $query->available()])
        ->orderBy('sort_order')
        ->get();

    $banners = Banner::active()->get();

    // Fetch active coupons for landing page showcase
    $coupons = Coupon::valid()->forLanding()->get();

    return view('landing', compact('featuredListings', 'categories', 'banners', 'coupons'));
});

// 2. Direct Android APK Download Route
Route::get('/download-apk', function () {
    $filePath = public_path('downloads/ojio-release-v1.0.apk');
    if (file_exists($filePath)) {
        return response()->download($filePath, 'OJIO-Marketplace-v1.0.apk', [
            'Content-Type' => 'application/vnd.android.package-archive',
        ]);
    }

    return back()->with('error', 'APK package is currently building.');
})->name('download.apk');

// 3. Admin Authentication Routes (Guests)
Route::prefix('admin')->group(function () {
    Route::get('/login', [AdminDashboardController::class, 'loginView'])->name('admin.login');
    Route::post('/login', [AdminDashboardController::class, 'login'])->middleware('throttle:5,1')->name('admin.login.submit');
    Route::post('/logout', [AdminDashboardController::class, 'logout'])->name('admin.logout');
});

// 4. Centralized Web Admin Dashboard (Protected by Admin Auth)
Route::prefix('admin')->middleware(['admin.auth'])->group(function () {
    Route::get('/', [AdminDashboardController::class, 'index'])->name('admin.dashboard');

    // Admin Profile & Security
    Route::get('/profile', [AdminDashboardController::class, 'profile'])->name('admin.profile');
    Route::get('/legal', [LegalDocumentController::class, 'index'])->name('admin.legal');
    Route::post('/legal/{slug}', [LegalDocumentController::class, 'update'])->whereIn('slug', ['terms', 'privacy'])->name('admin.legal.update');
    Route::post('/profile', [AdminDashboardController::class, 'updateProfile'])->name('admin.profile.update');
    Route::post('/change-password', [AdminDashboardController::class, 'changePassword'])->name('admin.password.update');

    Route::get('/listings', [AdminDashboardController::class, 'listings'])->name('admin.listings');
    Route::post('/listings/{id}/status', [AdminDashboardController::class, 'updateListingStatus'])->name('admin.listings.status');
    Route::get('/users', [AdminDashboardController::class, 'users'])->name('admin.users');
    Route::post('/users/{id}/toggle-block', [AdminDashboardController::class, 'toggleUserBlock'])->name('admin.users.block');

    // Coupons & Offers Management
    Route::get('/coupons', [AdminDashboardController::class, 'coupons'])->name('admin.coupons');
    Route::post('/coupons', [AdminDashboardController::class, 'storeCoupon'])->name('admin.coupons.store');
    Route::post('/coupons/{id}/toggle', [AdminDashboardController::class, 'toggleCoupon'])->name('admin.coupons.toggle');
    Route::post('/coupons/{id}/delete', [AdminDashboardController::class, 'deleteCoupon'])->name('admin.coupons.delete');

    Route::get('/categories', [AdminDashboardController::class, 'categories'])->name('admin.categories');
    Route::post('/categories', [AdminDashboardController::class, 'storeCategory'])->name('admin.categories.store');
    Route::post('/categories/{id}/update', [AdminDashboardController::class, 'updateCategory'])->name('admin.categories.update');
    Route::post('/categories/{id}/toggle-status', [AdminDashboardController::class, 'toggleCategoryStatus'])->name('admin.categories.toggle_status');
    Route::get('/monetization', [AdminDashboardController::class, 'monetization'])->name('admin.monetization');
    Route::post('/monetization/free-quota', [AdminDashboardController::class, 'updateFreeQuota'])->name('admin.free-quota.update');
    Route::post('/monetization/packages/{id}', [AdminDashboardController::class, 'updatePackage'])->name('admin.packages.update');
});
