<?php

namespace App\Services;

use App\Models\PushDevice;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class FcmService
{
    /** @param array<string, string> $data */
    public function send(PushDevice $device, string $title, string $body, array $data): void
    {
        $credentials = $this->credentials();
        $response = Http::withToken($this->accessToken($credentials))->timeout(8)->post(
            'https://fcm.googleapis.com/v1/projects/'.rawurlencode($credentials['project_id']).'/messages:send',
            ['message' => [
                'token' => $device->token, 'notification' => ['title' => $title, 'body' => $body], 'data' => $data,
                'android' => [
                    'priority' => 'high', 'ttl' => '86400s',
                    'notification' => ['channel_id' => 'ojio_activity', 'icon' => 'ic_notification', 'tag' => $data['event_id']],
                ],
            ]],
        );
        if ($response->successful()) {
            return;
        }
        $errors = $response->json('error.details', []);
        foreach (is_array($errors) ? $errors : [] as $error) {
            if (($error['@type'] ?? '') === 'type.googleapis.com/google.firebase.fcm.v1.FcmError'
                && ($error['errorCode'] ?? '') === 'UNREGISTERED') {
                PushDevice::whereKey($device->id)->where('token_hash', $device->token_hash)->delete();

                return;
            }
        }
        if ($response->status() === 401) {
            Cache::forget($this->cacheKey($credentials));
        }
        throw new RuntimeException('FCM delivery failed (HTTP '.$response->status().').');
    }

    /** @return array<string, mixed> */
    private function credentials(): array
    {
        $json = config('services.fcm.credentials_json');
        if (! $json && ($path = config('services.fcm.credentials_file'))) {
            $json = is_file($path) ? file_get_contents($path) : null;
        }
        $credentials = is_string($json) ? json_decode($json, true) : null;
        if (! is_array($credentials) || ($credentials['type'] ?? '') !== 'service_account'
            || empty($credentials['project_id']) || empty($credentials['client_email']) || empty($credentials['private_key'])
            || ! preg_match('/^[a-z][a-z0-9-]+$/', $credentials['project_id'])
            || (config('services.fcm.project_id') && config('services.fcm.project_id') !== $credentials['project_id'])) {
            throw new RuntimeException('FCM service account configuration is missing or does not match the configured project.');
        }

        return $credentials;
    }

    /** @param array<string, mixed> $credentials */
    private function cacheKey(array $credentials): string
    {
        return 'fcm_oauth_'.hash('sha256', $credentials['project_id'].$credentials['client_email'].($credentials['private_key_id'] ?? ''));
    }

    /** @param array<string, mixed> $credentials */
    private function accessToken(array $credentials): string
    {
        $cached = Cache::get($this->cacheKey($credentials));
        if (is_string($cached) && $cached !== '') {
            return $cached;
        }
        $encode = static fn (string $value): string => rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
        $header = $encode(json_encode(['alg' => 'RS256', 'typ' => 'JWT'], JSON_THROW_ON_ERROR));
        $claims = $encode(json_encode([
            'iss' => $credentials['client_email'], 'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token', 'iat' => time(), 'exp' => time() + 3600,
        ], JSON_THROW_ON_ERROR));
        $signature = '';
        if (! @openssl_sign($header.'.'.$claims, $signature, $credentials['private_key'], OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('FCM service account signing key is invalid.');
        }
        $response = Http::asForm()->timeout(8)->post('https://oauth2.googleapis.com/token', [
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $header.'.'.$claims.'.'.$encode($signature),
        ]);
        $token = $response->json('access_token');
        if (! $response->successful() || ! is_string($token) || $token === '') {
            throw new RuntimeException('FCM authentication failed (HTTP '.$response->status().').');
        }
        Cache::put($this->cacheKey($credentials), $token, max(1, min(3000, (int) $response->json('expires_in', 3600) - 120)));

        return $token;
    }
}
