<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Banner;
use Illuminate\Http\Request;

class BannerController extends Controller
{
    public function index(Request $request)
    {
        $placement = $request->query('placement', 'home_top');

        $banners = Banner::active()
            ->when($placement, function ($q) use ($placement) {
                return $q->where('placement', $placement);
            })
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $banners,
        ]);
    }

    public function recordClick($id)
    {
        $banner = Banner::findOrFail($id);
        $banner->increment('clicks_count');

        return response()->json([
            'status' => 'success',
            'message' => 'Click tracked',
            'target_url' => $banner->target_url,
        ]);
    }
}
