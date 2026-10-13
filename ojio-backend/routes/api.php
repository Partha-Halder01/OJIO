<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BannerController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\ChatController;
use App\Http\Controllers\Api\CouponController;
use App\Http\Controllers\Api\LegalDocumentController;
use App\Http\Controllers\Api\ListingController;
use App\Http\Controllers\Api\LocationController;
use App\Http\Controllers\Api\PremiumPackageController;
use App\Http\Controllers\Api\PushDeviceController;
use App\Http\Controllers\Api\WalletController;
use App\Http\Middleware\EnsureAccountActive;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    // Public routes
    Route::get('/locations/reverse', [LocationController::class, 'reverse'])->middleware('throttle:10,1');
    Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:10,1');
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:10,1');
    Route::post('/auth/firebase-login', [AuthController::class, 'firebaseLogin'])->middleware('throttle:10,1');
    Route::get('/categories', [CategoryController::class, 'index']);
    Route::get('/packages', [PremiumPackageController::class, 'index']);
    Route::get('/categories/{id}', [CategoryController::class, 'show']);
    Route::get('/listings', [ListingController::class, 'index']);
    Route::get('/listings/suggestions', [ListingController::class, 'suggestions'])->middleware('throttle:60,1');
    Route::get('/legal/{slug}', [LegalDocumentController::class, 'show'])->whereIn('slug', ['terms', 'privacy']);
    Route::get('/listings/{id}', [ListingController::class, 'show']);
    Route::get('/images/{id}', [ListingController::class, 'serveImage'])->name('listing-images.show');
    Route::get('/banners', [BannerController::class, 'index']);
    Route::post('/banners/{id}/click', [BannerController::class, 'recordClick']);

    // Coupons & Offers (Public)
    Route::get('/coupons', [CouponController::class, 'index']);
    Route::post('/coupons/validate', [CouponController::class, 'validateCoupon']);

    // Protected routes (Sanctum)
    Route::middleware(['auth:sanctum', EnsureAccountActive::class])->group(function () {
        Route::post('/user/push-device', [PushDeviceController::class, 'store'])->middleware('throttle:30,1');
        Route::delete('/user/push-device', [PushDeviceController::class, 'destroy'])->middleware('throttle:30,1');
        Route::get('/wallet', [WalletController::class, 'show']);
        Route::post('/wallet/topup', [WalletController::class, 'topup'])->middleware('throttle:10,1');
        Route::post('/payments/{id}/reconcile', [WalletController::class, 'reconcile'])->middleware('throttle:10,1');
        Route::post('/monetization/order', [PremiumPackageController::class, 'createOrder'])->middleware('throttle:10,1');
        Route::post('/monetization/wallet', [PremiumPackageController::class, 'payWithWallet']);
        Route::get('/chats', [ChatController::class, 'threads']);
        Route::get('/chats/{threadId}/messages', [ChatController::class, 'messages']);
        Route::post('/chats/send', [ChatController::class, 'sendMessage']);
        Route::post('/chats/open', [ChatController::class, 'open']);
        Route::post('/user/profile', [AuthController::class, 'updateProfile']);
        Route::get('/user/profile', [AuthController::class, 'profile']);
        Route::post('/user/location', [AuthController::class, 'updateLocation']);
        Route::post('/user/change-password', [AuthController::class, 'changePassword']);
        Route::post('/listings', [ListingController::class, 'store']);
        Route::match(['put', 'post'], '/listings/{id}', [ListingController::class, 'update']);
        Route::get('/user/my-ads', [ListingController::class, 'myAds']);
        Route::get('/user/my-ads/updates', [ListingController::class, 'adUpdates']);
        Route::post('/user/my-ads/updates/read', [ListingController::class, 'readAdUpdates']);
        Route::put('/listings/{id}/sold', [ListingController::class, 'markAsSold']);
        Route::put('/listings/{id}/status', [ListingController::class, 'updateStatus']);
        Route::delete('/listings/{id}', [ListingController::class, 'destroy']);
        Route::post('/monetization/verify-payment', [PremiumPackageController::class, 'verifyPayment']);
    });
});
