<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\RateLimiter;

class LocationController extends Controller
{
    public function reverse(Request $request): JsonResponse
    {
        $data = $request->validate(['latitude' => 'required|numeric|between:-90,90', 'longitude' => 'required|numeric|between:-180,180']);
        $latitude = (float) $data['latitude'];
        $longitude = (float) $data['longitude'];
        $location = Cache::remember('reverse_location:v2:'.round($latitude, 5).':'.round($longitude, 5), 86400, function () use ($latitude, $longitude) {
            abort_unless(RateLimiter::attempt('geocoding_provider', 1, fn () => true, 1), 429, 'Location lookup is busy. Please try again shortly.');
            $response = Http::timeout(15)->withUserAgent('OJIO Marketplace '.config('app.url'))
                ->get(config('services.geocoding.url'), ['lat' => $latitude, 'lon' => $longitude, 'lang' => 'en', 'radius' => 0.5, 'limit' => 5])->throw()->json();
            $features = collect($response['features'] ?? [])
                ->map(function (array $feature) use ($latitude, $longitude): array {
                    $coordinates = $feature['geometry']['coordinates'] ?? [];
                    $feature['distance'] = count($coordinates) === 2 && is_numeric($coordinates[0]) && is_numeric($coordinates[1])
                        ? $this->distanceMeters($latitude, $longitude, (float) $coordinates[1], (float) $coordinates[0])
                        : INF;

                    return $feature;
                })
                ->filter(fn (array $feature): bool => $feature['distance'] <= 500)
                ->sortBy('distance');
            $place = $features->first()['properties'] ?? [];
            $isSettlement = ($place['osm_key'] ?? '') === 'place'
                && in_array($place['osm_value'] ?? '', ['city', 'town', 'village'], true);
            $city = $this->firstName([$place['city'] ?? null, $isSettlement ? ($place['name'] ?? null) : null, $place['county'] ?? null]);
            abort_unless($city, 422, 'Unable to find a city. Please select your location manually.');
            $isArea = ($place['osm_key'] ?? '') === 'place'
                && in_array($place['osm_value'] ?? '', ['neighbourhood', 'suburb', 'quarter'], true);
            $area = $this->firstName([$place['suburb'] ?? null, $place['district'] ?? null, $isArea ? ($place['name'] ?? null) : null]);
            if (mb_strtolower($area) === mb_strtolower($city)) {
                $area = '';
            }

            return [
                'city' => $city, 'locality' => $area,
                'state' => $place['state'] ?? null, 'country' => $place['country'] ?? null,
                'places' => array_values(array_unique(array_filter([$city, $area, $place['county'] ?? null]))),
            ];
        });

        return response()->json(['status' => 'success', 'data' => $location]);
    }

    /** @param array<int, string|null> $values */
    private function firstName(array $values): string
    {
        foreach ($values as $value) {
            if (is_string($value) && trim($value) !== '') {
                return trim($value);
            }
        }

        return '';
    }

    private function distanceMeters(float $latitude, float $longitude, float $otherLatitude, float $otherLongitude): float
    {
        $latitudeDifference = deg2rad($otherLatitude - $latitude);
        $longitudeDifference = deg2rad($otherLongitude - $longitude);
        $a = sin($latitudeDifference / 2) ** 2
            + cos(deg2rad($latitude)) * cos(deg2rad($otherLatitude)) * sin($longitudeDifference / 2) ** 2;

        return 6371000 * 2 * asin(sqrt(min(1, max(0, $a))));
    }
}
