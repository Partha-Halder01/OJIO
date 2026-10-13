<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MarketplaceSetting;
use App\Models\PaymentOrder;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    private function userResponseData($user)
    {
        $user->refreshFreeQuota();
        $premiumStatus = $user->premiumStatus();
        if (PaymentOrder::where('user_id', $user->id)->where('purpose', 'premium')->where('status', 'paid')->exists()) {
            $user->paid_ads_quota = (int) PaymentOrder::where('user_id', $user->id)->where('purpose', 'premium')->where('status', 'paid')
                ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))->sum('remaining_ads');
        }

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'city' => $user->city,
            'state' => $user->state,
            'country' => $user->country,
            'latitude' => $user->latitude === null ? null : (float) $user->latitude,
            'longitude' => $user->longitude === null ? null : (float) $user->longitude,
            'avatar' => $user->avatar,
            'free_ads_posted' => (int) $user->free_ads_posted,
            'free_ads_limit' => MarketplaceSetting::freeAdLimit(),
            'free_quota_resets_at' => $user->free_quota_resets_at,
            'paid_ads_quota' => (int) ($user->paid_ads_quota ?? 0),
            ...$premiumStatus,
            'paid_quota_until' => $user->paid_quota_until,
            'wallet_balance_paise' => (int) $user->wallet_balance_paise,
            'can_post_free_ad' => (bool) $user->canPostFreeAd(),
            'role' => $user->role,
        ];
    }

    public function register(Request $request)
    {
        if ($request->filled('phone')) {
            $request->merge(['phone' => preg_replace('/^\+91/', '', trim($request->phone))]);
        }
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'phone' => ['required', 'string', 'regex:/^[6-9][0-9]{9}$/', 'unique:users,phone'],
            'email' => 'required|string|email|max:255|unique:users,email',
            'password' => 'required|string|min:6',
            'city' => 'nullable|string',
        ], ['phone.unique' => 'This mobile number is already used by another account.']);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'phone' => $validated['phone'] ?? null,
            'password' => Hash::make($validated['password']),
            'city' => $validated['city'] ?? 'Kolkata',
            'free_ads_posted' => 0,
        ]);

        $token = $user->createToken('ojio_mobile_token')->plainTextToken;

        return response()->json([
            'status' => 'success',
            'message' => 'Registration successful',
            'token' => $token,
            'user' => $this->userResponseData($user),
        ], 201);
    }

    public function login(Request $request)
    {
        $request->validate([
            'login' => 'required|string',
            'password' => 'required|string',
        ]);

        $login = $request->login;
        if (preg_match('/^(?:\+91)?[6-9][0-9]{9}$/', $login)) {
            $login = preg_replace('/^\+91/', '', $login);
        }
        $user = User::where('email', $login)
            ->orWhere('phone', $login)
            ->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid credentials provided.',
            ], 401);
        }

        if ($user->is_blocked) {
            return response()->json([
                'status' => 'error',
                'message' => 'This account has been suspended by administration.',
            ], 403);
        }

        $token = $user->createToken('ojio_mobile_token')->plainTextToken;

        return response()->json([
            'status' => 'success',
            'message' => 'Logged in successfully',
            'token' => $token,
            'user' => $this->userResponseData($user),
        ]);
    }

    public function firebaseLogin(Request $request)
    {
        $validated = $request->validate([
            'id_token' => 'required|string|max:10000',
            'name' => 'nullable|string|max:255',
            'firebase_uid' => 'nullable|string',
            'avatar' => 'nullable|string',
            'phone' => 'nullable|string',
        ]);

        $parts = explode('.', $validated['id_token']);
        abort_unless(count($parts) === 3, 401, 'Invalid Google token.');
        $decode = static fn (string $value) => base64_decode(strtr($value, '-_', '+/'), true);
        $header = json_decode($decode($parts[0]) ?: '', true);
        $claims = json_decode($decode($parts[1]) ?: '', true);
        abort_unless(is_array($header) && is_array($claims) && ($header['alg'] ?? '') === 'RS256' && is_string($header['kid'] ?? null), 401, 'Invalid Google token.');
        $certificates = Cache::remember('google_oauth_certificates', 1800, fn () => Http::timeout(15)
            ->get('https://www.googleapis.com/oauth2/v1/certs')->throw()->json());
        $certificate = $certificates[$header['kid'] ?? ''] ?? null;
        abort_unless(($header['alg'] ?? '') === 'RS256' && $certificate
            && openssl_verify($parts[0].'.'.$parts[1], $decode($parts[2]) ?: '', $certificate, OPENSSL_ALGO_SHA256) === 1
            && ($claims['aud'] ?? '') === config('services.google.client_id')
            && in_array($claims['iss'] ?? '', ['accounts.google.com', 'https://accounts.google.com'], true)
            && (int) ($claims['exp'] ?? 0) > time()
            && filter_var($claims['email_verified'] ?? false, FILTER_VALIDATE_BOOLEAN)
            && filter_var($claims['email'] ?? '', FILTER_VALIDATE_EMAIL), 401, 'Google authentication failed.');
        $email = $claims['email'];
        $validated['name'] = $claims['name'] ?? 'OJIO User';
        $validated['avatar'] = $claims['picture'] ?? null;
        $user = User::where('email', $email)->first();

        if ($user) {
            if ($user->is_blocked) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'This account has been suspended by administration.',
                ], 403);
            }

            if (! empty($validated['avatar']) && empty($user->avatar)) {
                $user->avatar = $validated['avatar'];
                $user->save();
            }
        } else {
            $user = User::create([
                'name' => ! empty($validated['name']) ? $validated['name'] : 'OJIO User',
                'email' => $email,
                'phone' => null,
                'avatar' => $validated['avatar'] ?? null,
                'password' => Hash::make(Str::random(32)),
                'city' => 'Kolkata',
                'free_ads_posted' => 0,
                'role' => 'user',
            ]);
        }

        $token = $user->createToken('ojio_mobile_token')->plainTextToken;

        return response()->json([
            'status' => 'success',
            'message' => 'Authenticated with Google successfully',
            'token' => $token,
            'user' => $this->userResponseData($user),
        ]);
    }

    public function changePassword(Request $request)
    {
        $user = $request->user();

        $request->validate([
            'current_password' => 'required|string',
            'new_password' => 'required|string|min:6|confirmed',
        ]);

        if (! Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'status' => 'error',
                'message' => 'The current password provided is incorrect.',
            ], 422);
        }

        $user->password = Hash::make($request->new_password);
        $user->save();

        return response()->json([
            'status' => 'success',
            'message' => 'Your password has been changed successfully.',
        ]);
    }

    public function profile(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'status' => 'success',
            'user' => $this->userResponseData($user),
        ]);
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();
        $request->merge(['phone' => preg_replace('/^\+91/', '', trim((string) $request->input('phone')))]);
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'phone' => ['required', 'string', 'regex:/^(?:\+91)?[6-9][0-9]{9}$/', 'unique:users,phone,'.$user->id],
            'city' => 'nullable|string',
            'state' => 'nullable|string',
            'country' => 'nullable|string',
        ], ['phone.unique' => 'This mobile number is already used by another account.']);

        if (array_key_exists('city', $validated) && $validated['city'] !== $user->city) {
            $validated['latitude'] = null;
            $validated['longitude'] = null;
        }
        $user->update($validated);

        return response()->json([
            'status' => 'success',
            'message' => 'Profile updated successfully',
            'user' => $this->userResponseData($user),
        ]);
    }

    public function updateLocation(Request $request): JsonResponse
    {
        $data = $request->validate([
            'city' => 'required|string|max:100',
            'state' => 'nullable|string|max:100',
            'country' => 'nullable|string|max:100',
            'latitude' => 'nullable|required_with:longitude|numeric|between:-90,90',
            'longitude' => 'nullable|required_with:latitude|numeric|between:-180,180',
        ]);
        $data['latitude'] = $data['latitude'] ?? null;
        $data['longitude'] = $data['longitude'] ?? null;
        $user = $request->user();
        $user->update($data);

        return response()->json([
            'status' => 'success',
            'user' => $this->userResponseData($user),
        ]);
    }
}
