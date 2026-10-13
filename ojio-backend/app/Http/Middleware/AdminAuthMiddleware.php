<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AdminAuthMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        if (! Auth::check()) {
            return redirect()->guest(route('admin.login'))->with('error', 'Please log in to access the Admin Console.');
        }

        if (Auth::user()->role !== 'admin' || Auth::user()->is_blocked) {
            Auth::logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return redirect()->route('admin.login')->with('error', 'Unauthorized access.');
        }

        return $next($request);
    }
}
