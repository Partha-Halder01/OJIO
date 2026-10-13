<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Jobs\BroadcastCouponNotification;
use App\Models\Category;
use App\Models\Coupon;
use App\Models\Listing;
use App\Models\MarketplaceSetting;
use App\Models\MonetizationOrder;
use App\Models\PremiumPackage;
use App\Models\User;
use App\Services\PushNotificationService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AdminDashboardController extends Controller
{
    // --- Admin Authentication ---
    public function loginView()
    {
        if (Auth::check() && Auth::user()->role === 'admin' && ! Auth::user()->is_blocked) {
            return redirect()->route('admin.dashboard');
        }

        return view('admin.login');
    }

    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        if (Auth::attempt(['email' => $credentials['email'], 'password' => $credentials['password'], 'role' => 'admin', 'is_blocked' => false], $request->boolean('remember'))) {
            $request->session()->regenerate();

            return redirect()->intended(route('admin.dashboard'))->with('success', 'Welcome back, Administrator!');
        }

        return back()->withInput($request->only('email', 'remember'))->with('error', 'Invalid admin credentials or account does not have administrator privileges.');
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login')->with('success', 'Logged out of administrator console successfully.');
    }

    // --- Admin Profile & Security ---
    public function profile()
    {
        $admin = Auth::user();

        return view('admin.profile', compact('admin'));
    }

    public function updateProfile(Request $request)
    {
        $admin = Auth::user();
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:users,email,'.$admin->id,
            'phone' => 'nullable|string|max:20',
            'city' => 'nullable|string|max:100',
        ]);

        $admin->update($validated);

        return back()->with('success', 'Administrator profile details updated successfully.');
    }

    public function changePassword(Request $request)
    {
        $admin = Auth::user();
        $request->validate([
            'current_password' => 'required|string',
            'password' => 'required|string|min:6|confirmed',
        ]);

        if (! Hash::check($request->current_password, $admin->password)) {
            return back()->with('error', 'The current password provided is incorrect.');
        }

        $admin->password = Hash::make($request->password);
        $admin->save();

        return back()->with('success', 'Administrator password has been successfully updated.');
    }

    // --- Management Modules ---
    public function categories(Request $request)
    {
        $parentId = $request->get('parent_id');
        $parentCategory = null;
        $breadcrumbs = collect();

        if ($parentId) {
            $parentCategory = Category::findOrFail($parentId);
            $curr = $parentCategory;
            $seen = [];
            while ($curr && ! isset($seen[$curr->id])) {
                $seen[$curr->id] = true;
                $breadcrumbs->prepend($curr);
                $curr = $curr->parent;
            }
        }

        $query = Category::where('parent_id', $parentId)
            ->withCount([
                'listings as listings_count',
                'listings as active_listings_count' => function ($query) {
                    $query->where('status', 'active');
                },
                'listings as sold_listings_count' => function ($query) {
                    $query->where('status', 'sold');
                },
            ]);

        if ($request->has('status') && $request->status != '') {
            $query->where('is_active', $request->status == 'active' ? 1 : 0);
        }

        $categoriesList = $query->orderBy('sort_order')->orderBy('name')->get();

        // We also need all primary categories for the dropdowns in modals
        $allPrimary = Category::whereNull('parent_id')->get();

        return view('admin.categories', compact('categoriesList', 'parentCategory', 'breadcrumbs', 'allPrimary'));
    }

    public function toggleCategoryStatus($id)
    {
        $category = Category::findOrFail($id);
        $category->is_active = ! $category->is_active;
        $category->save();

        $status = $category->is_active ? 'restored' : 'removed';

        return back()->with('success', "Category has been {$status} successfully.");
    }

    public function storeCategory(Request $request)
    {
        $this->saveCategory($request);

        return back()->with('success', 'Category added successfully!');
    }

    public function updateCategory(Request $request, $id)
    {
        $this->saveCategory($request, Category::findOrFail($id));

        return back()->with('success', 'Category updated successfully!');
    }

    private function saveCategory(Request $request, ?Category $category = null): Category
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'slug' => ['required', 'string', 'max:255', 'regex:/^[a-z0-9]+(?:-[a-z0-9]+)*$/', Rule::unique('categories', 'slug')->ignore($category?->id)],
            'icon' => 'nullable|image|max:2048',
            'parent_id' => 'nullable|integer|exists:categories,id',
            'sort_order' => 'sometimes|integer|min:0|max:9999',
            'brands' => 'sometimes|nullable|string|max:5000',
        ]);

        return DB::transaction(function () use ($request, $category, $validated) {
            $categories = Category::orderBy('id')->lockForUpdate()->get()->keyBy('id');
            $category = $category ? $categories->get($category->id) : new Category;
            $parentId = $validated['parent_id'] ?? null;
            $parent = $parentId ? $categories->get($parentId) : null;
            if ($parentId && (! $parent || $parent->id === $category->id || $parent->parent_id || ($category->exists && $categories->contains('parent_id', $category->id)))) {
                throw ValidationException::withMessages(['parent_id' => 'Choose a main category. Categories with children must remain main categories.']);
            }
            if (array_key_exists('brands', $validated)) {
                $brands = collect(preg_split('/[\r\n,]+/', $validated['brands'] ?? ''))->map(fn ($brand) => trim($brand))->filter()->unique()->values();
                if ($brands->count() > 100 || $brands->contains(fn ($brand) => mb_strlen($brand) > 100)) {
                    throw ValidationException::withMessages(['brands' => 'Use up to 100 brands, each at most 100 characters.']);
                }
                $schema = $category->custom_attributes_schema ?? [];
                $schema['brand'] = $brands->all();
                $validated['custom_attributes_schema'] = $schema;
            }
            unset($validated['brands'], $validated['icon']);
            if ($request->hasFile('icon')) {
                $validated['icon'] = '/storage/'.$request->file('icon')->store('categories', 'public');
            }
            $validated['parent_id'] = $parentId;
            $category->fill($validated)->save();

            return $category;
        });
    }

    public function index()
    {
        $stats = [
            'total_users' => User::count(),
            'active_listings' => Listing::where('status', 'active')->count(),
            'pending_listings' => Listing::where('status', 'pending')->count(),
            'total_revenue' => MonetizationOrder::where('payment_status', 'paid')->sum('amount'),
        ];

        $recentListings = Listing::with(['user', 'category', 'images'])->latest()->take(6)->get();
        $recentUsers = User::latest()->take(6)->get();

        return view('admin.dashboard', compact('stats', 'recentListings', 'recentUsers'));
    }

    public function listings(Request $request)
    {
        $request->validate([
            'status' => 'nullable|in:all,active,pending,rejected,sold,expired',
            'parent_id' => 'nullable|integer|exists:categories,id',
            'category_id' => 'nullable|integer|exists:categories,id',
            'period' => 'nullable|in:all,today,yesterday,7_days,30_days',
        ]);
        $status = $request->query('status', 'all');
        $parentId = $request->query('parent_id');
        $categoryId = $request->query('category_id');
        $period = $request->query('period') ?: 'all';

        $query = Listing::with(['user', 'category', 'images']);

        if ($period !== 'all') {
            $today = Carbon::now('Asia/Kolkata')->startOfDay();
            $start = match ($period) {
                'yesterday' => $today->copy()->subDay(),
                '7_days' => $today->copy()->subDays(6),
                '30_days' => $today->copy()->subDays(29),
                default => $today->copy(),
            };
            $end = $period === 'yesterday' ? $today->copy() : $today->copy()->addDay();
            $query->where('created_at', '>=', $start->setTimezone(config('app.timezone')))
                ->where('created_at', '<', $end->setTimezone(config('app.timezone')));
        }

        if ($status !== 'all') {
            $query->where('status', $status);
        }

        if ($categoryId) {
            $query->where('category_id', $categoryId);
        } elseif ($parentId) {
            $query->whereIn('category_id', Category::descendantIds((int) $parentId));
        }

        $listings = $query->latest()->paginate(15)->withQueryString();

        // Fetch all primary categories
        $parentCategories = Category::whereNull('parent_id')->get();

        // Fetch subcategories if parent is selected
        $subCategories = collect();
        if ($parentId) {
            $subCategories = Category::whereIn('id', Category::descendantIds((int) $parentId))->where('id', '!=', $parentId)->orderBy('sort_order')->get();
        }

        return view('admin.listings', compact('listings', 'status', 'parentCategories', 'subCategories', 'parentId', 'categoryId', 'period'));
    }

    public function updateListingStatus(Request $request, $id)
    {
        $listing = Listing::findOrFail($id);
        abort_if(in_array($listing->status, ['sold', 'expired'], true), 422, 'Closed listings cannot be approved or rejected.');
        $request->validate([
            'status' => 'required|in:active,pending,rejected',
            'rejection_reason' => 'nullable|string',
        ]);

        DB::transaction(function () use ($request, $id) {
            $listing = Listing::lockForUpdate()->findOrFail($id);
            abort_if(in_array($listing->status, ['sold', 'expired'], true), 422, 'Closed listings cannot be approved or rejected.');
            $listing->fill([
                'status' => $request->status,
                'rejection_reason' => $request->status === 'rejected' ? $request->rejection_reason : null,
            ]);
            if ($listing->isDirty(['status', 'rejection_reason'])) {
                $listing->admin_update_version++;
                $listing->save();
                app(PushNotificationService::class)->notify(
                    (int) $listing->user_id, 'ad_status', 'Ad update',
                    match ($listing->status) {
                        'active' => 'Your ad has been approved.',
                        'rejected' => 'Your ad was rejected. Open My Ads for details.',
                        default => 'Your ad is under review.',
                    },
                    ['listing_id' => (string) $listing->id, 'event_id' => 'ad_'.$listing->id.'_'.$listing->admin_update_version],
                );
            }
        });

        return back()->with('success', "Listing status updated to {$request->status}!");
    }

    public function users()
    {
        $users = User::withCount('listings')->latest()->paginate(20);

        return view('admin.users', compact('users'));
    }

    public function toggleUserBlock($id)
    {
        $user = User::findOrFail($id);
        abort_if($user->role === 'admin', 422, 'Administrator accounts cannot be suspended here.');
        $user->is_blocked = ! $user->is_blocked;
        $user->save();

        $state = $user->is_blocked ? 'blocked' : 'unblocked';

        return back()->with('success', "User has been {$state} successfully.");
    }

    public function monetization()
    {
        $totalRevenue = MonetizationOrder::where('payment_status', 'paid')->sum('amount');
        $orders = MonetizationOrder::with(['user:id,name', 'listing:id,title'])->latest()->paginate(15);
        $packages = PremiumPackage::all();
        $freeAdsLimit = MarketplaceSetting::freeAdLimit();
        $premiumUsersCount = User::where('is_premium', true)->orWhere('has_diamond_badge', true)->count();
        $premiumUsers = User::where('is_premium', true)->orWhere('has_diamond_badge', true)->latest()->take(10)->get();
        $walletBalance = User::sum('wallet_balance_paise') / 100;
        $walletTransactions = DB::table('wallet_transactions')
            ->join('users', 'users.id', '=', 'wallet_transactions.user_id')
            ->select('wallet_transactions.*', 'users.name')->orderByDesc('wallet_transactions.id')->limit(25)->get();

        return view('admin.monetization', compact('totalRevenue', 'orders', 'packages', 'premiumUsersCount', 'premiumUsers', 'walletBalance', 'walletTransactions', 'freeAdsLimit'));
    }

    public function updateFreeQuota(Request $request): RedirectResponse
    {
        $data = $request->validate(['free_ads_limit' => 'required|integer|min:0|max:1000']);
        MarketplaceSetting::updateOrCreate(['key' => 'free_ads_limit'], ['value' => $data['free_ads_limit']]);

        return back()->with('success', 'Free ad quota updated.');
    }

    public function updatePackage(Request $request, $id)
    {
        $package = PremiumPackage::findOrFail($id);
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'price' => 'required|numeric|min:0',
            'description' => 'nullable|string|max:500',
            'ads_limit' => 'nullable|integer|min:0',
            'duration_days' => 'nullable|integer|min:0',
        ]);

        $package->update($validated);

        return back()->with('success', "Package '{$package->name}' updated successfully!");
    }

    public function coupons()
    {
        $coupons = Coupon::latest()->get();

        return view('admin.coupons', compact('coupons'));
    }

    public function storeCoupon(Request $request)
    {
        $request->merge(['code' => strtoupper(trim((string) $request->input('code')))]);
        $validated = $request->validate([
            'code' => 'required|string|max:30|unique:coupons,code',
            'description' => 'required|string|max:255',
            'type' => 'required|in:percentage,fixed',
            'value' => ['required', 'numeric', 'min:1', Rule::when($request->input('type') === 'percentage', 'max:100')],
            'show_on_landing' => 'nullable|boolean',
            'show_in_app' => 'nullable|boolean',
            'expires_at' => 'nullable|date',
            'usage_limit' => 'nullable|integer|min:0',
        ]);

        $validated['code'] = strtoupper(trim($validated['code']));
        $validated['show_on_landing'] = $request->boolean('show_on_landing');
        $validated['show_in_app'] = $request->boolean('show_in_app');
        $validated['is_active'] = true;
        $validated['usage_limit'] = ($validated['usage_limit'] ?? 0) > 0 ? $validated['usage_limit'] : null;

        $coupon = Coupon::create($validated);
        if ($coupon->show_in_app && $coupon->isValid() && config('services.fcm.enabled')) {
            BroadcastCouponNotification::dispatch((int) $coupon->id)
                ->onConnection(config('services.fcm.queue_connection'))->onQueue('push')->afterCommit();
        }

        return back()->with('success', 'Promotional offer coupon created successfully!');
    }

    public function toggleCoupon($id)
    {
        $coupon = Coupon::findOrFail($id);
        $coupon->is_active = ! $coupon->is_active;
        $coupon->save();

        $status = $coupon->is_active ? 'activated' : 'deactivated';

        return back()->with('success', "Coupon {$coupon->code} has been {$status}.");
    }

    public function deleteCoupon($id)
    {
        Coupon::findOrFail($id)->delete();

        return back()->with('success', 'Coupon deleted.');
    }
}
