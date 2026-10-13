<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Listing;
use App\Models\ListingImage;
use App\Models\MarketplaceSetting;
use App\Models\PaymentOrder;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class ListingController extends Controller
{
    public function suggestions(Request $request): JsonResponse
    {
        $request->validate(['query' => 'required|string|max:200']);
        if (mb_strlen(trim($request->query('query'))) < 2) {
            return response()->json(['status' => 'success', 'data' => []]);
        }
        $request->query->set('page', 1);
        $response = $this->index($request)->getData(true);
        $titles = collect($response['data']['data'])->pluck('title')->unique()->take(6)->values();

        return response()->json(['status' => 'success', 'data' => $titles]);
    }

    public function index(Request $request)
    {
        $request->validate([
            'category_id' => 'nullable|integer|exists:categories,id',
            'query' => 'nullable|string|max:200',
            'min_price' => 'nullable|numeric|min:0',
            'max_price' => ['nullable', 'numeric', 'min:0', ...($request->filled('min_price') ? ['gte:min_price'] : [])],
            'latitude' => 'nullable|required_with:longitude|numeric|between:-90,90',
            'longitude' => 'nullable|required_with:latitude|numeric|between:-180,180',
            'radius' => 'nullable|numeric|min:1|max:200',
            'page' => 'nullable|integer|min:1',
            'city' => 'nullable|string|max:150',
            'feed' => 'nullable|in:recommended,nearby',
        ]);
        $recommended = $request->input('feed') === 'recommended';
        abort_if($request->input('feed') === 'nearby' && ! $request->filled('city') && ! $request->filled('latitude'), 422, 'Select a location to browse nearby items.');
        $query = Listing::with(['images', 'category', 'user:id,name,phone,avatar,city,has_diamond_badge,is_premium', 'user.paidPremiumOrders'])
            ->where('status', 'active')->whereHas('user', fn ($query) => $query->where('is_blocked', false));

        // Filter by category (including subcategories)
        if ($request->filled('category_id')) {
            $allIds = Category::descendantIds((int) $request->category_id);

            $query->whereIn('category_id', $allIds);
        }
        // Filter by city
        if ($request->filled('city') && ! $recommended && ! $request->filled('latitude')) {
            $query->whereIn(DB::raw('LOWER(city)'), $this->cityNames($request->city));
        }

        // Price range
        if ($request->filled('min_price')) {
            $query->where('price', '>=', $request->min_price);
        }
        if ($request->filled('max_price')) {
            $query->where('price', '<=', $request->max_price);
        }

        // Keyword search
        if ($request->filled('query')) {
            $term = $request->query('query');
            $query->where(function ($q) use ($term) {
                $q->where('title', 'like', "%{$term}%")
                    ->orWhere('description', 'like', "%{$term}%");
            });
        }

        // Proximity / Geolocation Radius filter (in KM)
        if (! $recommended && $request->filled('latitude') && $request->filled('longitude')) {
            $lat = (float) $request->latitude;
            $lng = (float) $request->longitude;
            $radius = (float) ($request->radius ?? 50);

            // SQLite doesn't natively support ACOS, COS, SIN. So we use bounding box to filter items
            // ~111km per latitude degree
            $latDiff = $radius / 111.0;
            // Longitude diff changes based on latitude
            $lngDiff = min(180, $radius / (111.0 * max(0.000001, cos(deg2rad($lat)))));

            $query->whereBetween('latitude', [max(-90, $lat - $latDiff), min(90, $lat + $latDiff)]);
            if ($lngDiff < 180) {
                $query->where(function ($query) use ($lng, $lngDiff) {
                    if ($lng - $lngDiff < -180) {
                        $query->where('longitude', '>=', $lng - $lngDiff + 360)->orWhere('longitude', '<=', $lng + $lngDiff);
                    } elseif ($lng + $lngDiff > 180) {
                        $query->where('longitude', '>=', $lng - $lngDiff)->orWhere('longitude', '<=', $lng + $lngDiff - 360);
                    } else {
                        $query->whereBetween('longitude', [$lng - $lngDiff, $lng + $lngDiff]);
                    }
                });
            }

            $all_listings = $query->get();

            // Precise filtering in PHP using Haversine
            $filtered = $all_listings->filter(function ($item) use ($lat, $lng, $radius) {
                if ($item->latitude === null || $item->longitude === null) {
                    return false;
                }

                $earthRadius = 6371; // km
                $latFrom = deg2rad($lat);
                $lonFrom = deg2rad($lng);
                $latTo = deg2rad($item->latitude);
                $lonTo = deg2rad($item->longitude);

                $latDelta = $latTo - $latFrom;
                $lonDelta = $lonTo - $lonFrom;

                $angle = 2 * asin(sqrt(min(1, max(0, pow(sin($latDelta / 2), 2) +
                    cos($latFrom) * cos($latTo) * pow(sin($lonDelta / 2), 2)))));
                $distance = $angle * $earthRadius;

                $item->distance = $distance; // dynamic property

                return $distance <= $radius;
            })->sortBy([['distance', 'asc'], ['id', 'asc']])->values();

            $page = $request->input('page', 1);
            $perPage = 20;
            $paginated = new LengthAwarePaginator(
                $filtered->forPage($page, $perPage)->values(),
                $filtered->count(),
                $perPage,
                $page,
                ['path' => $request->url(), 'query' => $request->query()]
            );

            return response()->json([
                'status' => 'success',
                'data' => $paginated,
            ]);
        } else {
            if ($recommended && $request->filled('city')) {
                $cities = $this->cityNames($request->city);
                $placeholders = implode(',', array_fill(0, count($cities), '?'));
                $query->orderByRaw("CASE WHEN LOWER(city) IN ({$placeholders}) THEN 0 ELSE 1 END", $cities);
            }
            $query->orderBy('is_featured', 'desc')->latest();
        }

        $listings = $query->paginate(20);

        return response()->json([
            'status' => 'success',
            'data' => $listings,
        ]);
    }

    private function cityNames(string $city): array
    {
        $city = strtolower(trim($city));

        return match ($city) {
            'mumbai', 'bombay' => ['mumbai', 'bombay'],
            'kolkata', 'calcutta' => ['kolkata', 'calcutta'],
            'bengaluru', 'bangalore' => ['bengaluru', 'bangalore'],
            'chennai', 'madras' => ['chennai', 'madras'],
            'delhi', 'new delhi', 'delhi ncr' => ['delhi', 'new delhi', 'delhi ncr'],
            default => [$city],
        };
    }

    public function show($id)
    {
        $listing = Listing::with(['images', 'category', 'user:id,name,phone,avatar,city,has_diamond_badge,is_premium,created_at', 'user.paidPremiumOrders'])
            ->findOrFail($id);

        $listing->increment('views_count');

        return response()->json([
            'status' => 'success',
            'data' => $listing,
        ]);
    }

    public function store(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'post_request_id' => 'nullable|uuid',
            'category_id' => 'required|exists:categories,id',
            'title' => 'required|string|max:150',
            'description' => 'required|string',
            'price' => 'required|numeric|min:0',
            'is_negotiable' => 'boolean',
            'city' => 'required|string',
            'state' => 'nullable|string',
            'locality' => 'nullable|string',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'phone_number' => 'nullable|string',
            'hide_phone' => 'boolean',
            'attributes' => 'nullable|array',
            'images' => 'required|array|min:1|max:10', // array of image URLs or base64
            'images.*' => 'string',
        ]);
        abort_unless(Category::available()->whereKey($validated['category_id'])->exists(), 422, 'This category is unavailable. Please choose another category.');

        return DB::transaction(function () use ($user, $validated) {
            $user = User::lockForUpdate()->findOrFail($user->id);
            if (! empty($validated['post_request_id'])) {
                $existing = Listing::withTrashed()->where('user_id', $user->id)->where('post_request_id', $validated['post_request_id'])->first();
                if ($existing) {
                    return response()->json(['status' => 'success', 'data' => $existing->load('images', 'category')], 201);
                }
            }
            abort_if($user->is_blocked, 403, 'Your account is suspended.');
            abort_unless(preg_match('/^(?:\+91)?[6-9][0-9]{9}$/', $user->phone ?? ''), 422, 'Please add a valid contact number to your profile.');
            if (! $user->canPostFreeAd()) {
                return response()->json(['status' => 'payment_required', 'message' => 'Please choose a premium package to publish this ad.'], 402);
            }
            $freeLimit = MarketplaceSetting::freeAdLimit();
            $requiresPayment = $user->free_ads_posted >= $freeLimit;
            $slug = Str::slug($validated['title']).'-'.Str::random(6);

            $listing = Listing::create([
                'user_id' => $user->id,
                'post_request_id' => $validated['post_request_id'] ?? null,
                'category_id' => $validated['category_id'],
                'title' => $validated['title'],
                'slug' => $slug,
                'description' => $validated['description'],
                'price' => $validated['price'],
                'is_negotiable' => $validated['is_negotiable'] ?? false,
                'city' => $validated['city'],
                'state' => $validated['state'] ?? null,
                'locality' => $validated['locality'] ?? null,
                'latitude' => $validated['latitude'] ?? null,
                'longitude' => $validated['longitude'] ?? null,
                'phone_number' => $user->phone,
                'hide_phone' => $validated['hide_phone'] ?? false,
                'attributes' => $validated['attributes'] ?? [],
                'status' => 'active',
                'is_paid_ad' => $requiresPayment,
            ]);

            // Save images
            foreach ($validated['images'] as $index => $imageUrl) {
                if (is_string($imageUrl) && str_starts_with($imageUrl, 'local://')) {
                    $imageUrl = 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=800&auto=format&fit=crop&q=80';
                }
                // If it is a base64 image, we keep it as is since the DB column is LONGTEXT.

                ListingImage::create([
                    'listing_id' => $listing->id,
                    'image_path' => $imageUrl,
                    'is_primary' => ($index === 0),
                    'sort_order' => $index,
                ]);
            }

            // Increment user ad count or decrement paid quota
            if ($user->free_ads_posted < $freeLimit) {
                $user->increment('free_ads_posted');
                if ($user->free_ads_posted >= $freeLimit && ! $user->free_quota_resets_at) {
                    $user->free_quota_resets_at = now()->addDays(30);
                    $user->save();
                }
            } else {
                $credit = PaymentOrder::where('user_id', $user->id)->where('purpose', 'premium')
                    ->where('status', 'paid')->where('remaining_ads', '>', 0)
                    ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))
                    ->orderByRaw('CASE WHEN expires_at IS NULL THEN 1 ELSE 0 END')->orderBy('expires_at')->orderBy('id')
                    ->lockForUpdate()->first();
                if ($credit) {
                    $credit->decrement('remaining_ads');
                    $user->paid_ads_quota = (int) PaymentOrder::where('user_id', $user->id)->where('purpose', 'premium')->where('status', 'paid')
                        ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))->sum('remaining_ads');
                    $user->save();
                } else {
                    $user->decrement('paid_ads_quota');
                }
            }

            return response()->json([
                'status' => 'success',
                'message' => 'Listing published successfully!',
                'data' => $listing->load('images', 'category'),
            ], 201);
        });
    }

    public function update(Request $request, $id)
    {
        $user = $request->user();
        $listing = Listing::where('user_id', $user->id)->findOrFail($id);

        if ($listing->status === 'sold') {
            return response()->json([
                'status' => 'error',
                'message' => 'This ad has already been marked as SOLD and cannot be edited.',
            ], 422);
        }

        $validated = $request->validate([
            'category_id' => 'nullable|exists:categories,id',
            'title' => 'required|string|max:150',
            'description' => 'required|string',
            'price' => 'required|numeric|min:0',
            'is_negotiable' => 'boolean',
            'city' => 'required|string',
            'state' => 'nullable|string',
            'locality' => 'nullable|string',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'phone_number' => 'nullable|string',
            'hide_phone' => 'boolean',
            'attributes' => 'nullable|array',
            'images' => 'nullable|array',
            'images.*' => 'string',
        ]);

        return DB::transaction(function () use ($listing, $validated, $request) {
            if (! empty($validated['category_id']) && (int) $validated['category_id'] !== $listing->category_id) {
                abort_unless(Category::available()->whereKey($validated['category_id'])->exists(), 422, 'This category is unavailable. Please choose another category.');
            }
            $listing->title = $validated['title'];
            $listing->description = $validated['description'];
            $listing->price = $validated['price'];
            $listing->is_negotiable = $validated['is_negotiable'] ?? $listing->is_negotiable;
            $listing->city = $validated['city'];
            if ($request->has('state')) {
                $listing->state = $validated['state'];
            }
            if ($request->has('locality')) {
                $listing->locality = $validated['locality'];
            }
            if ($request->has('latitude')) {
                $listing->latitude = $validated['latitude'];
            }
            if ($request->has('longitude')) {
                $listing->longitude = $validated['longitude'];
            }
            $listing->phone_number = $request->user()->phone;
            if ($request->has('hide_phone')) {
                $listing->hide_phone = $validated['hide_phone'];
            }
            if ($request->has('attributes')) {
                $listing->attributes = $validated['attributes'];
            }

            if ($listing->status === 'rejected') {
                $listing->status = 'active';
            }

            $listing->save();

            if ($request->has('images') && is_array($request->images) && count($request->images) > 0) {
                $existingImages = $listing->images()->get()->keyBy(fn (ListingImage $image): string => $image->image_path);
                $retainedIds = [];
                foreach ($request->images as $index => $imageUrl) {
                    if ($existingImages->has($imageUrl)) {
                        $image = $existingImages->get($imageUrl);
                        $image->update(['is_primary' => $index === 0, 'sort_order' => $index]);
                        $retainedIds[] = $image->id;

                        continue;
                    }
                    if (is_string($imageUrl) && str_starts_with($imageUrl, 'local://')) {
                        $imageUrl = 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=800&auto=format&fit=crop&q=80';
                    }
                    // If it is a base64 image, we keep it as is since the DB column is LONGTEXT.

                    $image = ListingImage::create([
                        'listing_id' => $listing->id,
                        'image_path' => $imageUrl,
                        'is_primary' => ($index === 0),
                        'sort_order' => $index,
                    ]);
                    $retainedIds[] = $image->id;
                }
                $listing->images()->whereNotIn('id', $retainedIds)->delete();
            }

            return response()->json([
                'status' => 'success',
                'message' => 'Listing updated successfully! Changes are live in the marketplace.',
                'data' => $listing->fresh()->load('images', 'category'),
            ]);
        });
    }

    public function myAds(Request $request)
    {
        $user = $request->user();
        $user->refreshFreeQuota();
        $ads = Listing::with('images', 'category')
            ->where('user_id', $user->id)
            ->latest()
            ->get();

        return response()->json([
            'status' => 'success',
            'free_ads_used' => $user->free_ads_posted,
            'free_ads_limit' => MarketplaceSetting::freeAdLimit(),
            'free_quota_resets_at' => $user->free_quota_resets_at,
            'can_post_free' => $user->canPostFreeAd(),
            'data' => $ads,
        ]);
    }

    public function adUpdates(Request $request): JsonResponse
    {
        return response()->json([
            'status' => 'success',
            'has_updates' => Listing::where('user_id', $request->user()->id)
                ->whereColumn('admin_update_version', '>', 'admin_seen_version')->exists(),
        ]);
    }

    public function readAdUpdates(Request $request): JsonResponse
    {
        $data = $request->validate([
            'updates' => 'present|array|max:1000',
            'updates.*.id' => 'required|integer|min:1',
            'updates.*.version' => 'required|integer|min:0',
        ]);
        foreach ($data['updates'] as $update) {
            // Acknowledge only the revision actually loaded, never a newer change.
            Listing::where('user_id', $request->user()->id)->whereKey($update['id'])
                ->where('admin_update_version', '>=', $update['version'])
                ->where('admin_seen_version', '<', $update['version'])
                ->update(['admin_seen_version' => $update['version']]);
        }

        return $this->adUpdates($request);
    }

    public function markAsSold(Request $request, $id)
    {
        $user = $request->user();
        $listing = Listing::where('user_id', $user->id)->findOrFail($id);
        $listing->update(['status' => 'sold']);

        return response()->json([
            'status' => 'success',
            'message' => 'Listing marked as sold!',
            'data' => $listing,
        ]);
    }

    public function updateStatus(Request $request, $id)
    {
        $user = $request->user();
        $listing = Listing::where('user_id', $user->id)->findOrFail($id);
        $status = $request->input('status', 'active');
        $listing->update(['status' => $status]);

        return response()->json([
            'status' => 'success',
            'message' => "Listing status updated to {$status}!",
            'data' => $listing,
        ]);
    }

    public function destroy(Request $request, $id)
    {
        $user = $request->user();
        $listing = Listing::where('user_id', $user->id)->findOrFail($id);
        $listing->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Listing deleted successfully!',
        ]);
    }

    public function serveImage(Request $request, int $id): Response
    {
        $image = ListingImage::findOrFail($id);
        $path = $image->getRawOriginal('image_path') ?? '';

        if (str_starts_with($path, 'data:image/')) {
            abort_unless(preg_match('/^data:image\/(?:jpeg|jpg|png|webp|gif);base64,/', $path, $matches), 404);
            $binary = base64_decode(substr($path, strlen($matches[0])), true);
            abort_unless($binary !== false && $binary !== '', 404);
            $details = @getimagesizefromstring($binary);
            $mime = $details['mime'] ?? null;
            abort_unless(in_array($mime, ['image/jpeg', 'image/png', 'image/webp', 'image/gif'], true), 404);

            $response = response($binary, 200, [
                'Content-Type' => $mime,
                'Cache-Control' => 'public, max-age=86400',
                'X-Content-Type-Options' => 'nosniff',
            ]);
            $response->setEtag(hash('sha256', $binary));
            $response->isNotModified($request);

            return $response;
        }

        $url = $image->image_path;
        if (filter_var($url, FILTER_VALIDATE_URL) && in_array(parse_url($url, PHP_URL_SCHEME), ['http', 'https'], true)) {
            return redirect($url);
        }

        abort(404);
    }
}
