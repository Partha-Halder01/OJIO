<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PushDevice;
use App\Services\PushCampaignService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PushDeviceController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'device_key' => ['required', 'string', 'regex:/\\A[a-f0-9]{64}\\z/'],
            'token' => ['required', 'string', 'regex:/\\A[A-Za-z0-9:_-]{20,4096}\\z/'],
            'chat_enabled' => ['required', 'boolean'],
            'marketing_enabled' => ['sometimes', 'boolean'],
        ]);
        DB::transaction(function () use ($request, $data): void {
            $keyHash = hash('sha256', $data['device_key']);
            $tokenHash = hash('sha256', $data['token']);
            $existing = PushDevice::where('token_hash', $tokenHash)->lockForUpdate()->first();
            abort_if($existing && ! hash_equals($existing->device_key_hash, $keyHash), 409, 'Device registration does not match this installation.');
            PushDevice::updateOrCreate(['device_key_hash' => $keyHash], [
                'user_id' => $request->user()->id,
                'personal_access_token_id' => (int) $request->user()->currentAccessToken()?->getKey() ?: null,
                'token' => $data['token'], 'token_hash' => $tokenHash,
                'chat_enabled' => $data['chat_enabled'], 'last_seen_at' => now(),
                'marketing_enabled' => $data['marketing_enabled'] ?? false,
            ]);
        });
        app(PushCampaignService::class)->welcome((int) $request->user()->id);

        return response()->json(['status' => 'success']);
    }

    public function destroy(Request $request): JsonResponse
    {
        $data = $request->validate(['device_key' => ['required', 'string', 'regex:/\\A[a-f0-9]{64}\\z/']]);
        PushDevice::where('user_id', $request->user()->id)->where('device_key_hash', hash('sha256', $data['device_key']))->delete();

        return response()->json(['status' => 'success']);
    }
}
