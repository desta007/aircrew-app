<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Protects the admin monitoring endpoints (Phase 3 hardening).
 *
 * Enforced only when ADMIN_API_TOKEN is configured: the request must send a
 * matching `X-Admin-Token` header. When the token is unset (local/demo) the
 * endpoints stay open so the static dashboard keeps working — production MUST
 * set ADMIN_API_TOKEN. See docs/PHASE3_PAYMENTS_SETUP.md.
 */
class EnsureAdminToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $expected = config('admin.token');

        if (! empty($expected)) {
            $provided = $request->header('X-Admin-Token') ?? $request->query('admin_token');
            if (! is_string($provided) || ! hash_equals($expected, $provided)) {
                return response()->json(['message' => 'Unauthorized admin access.'], 401);
            }
        }

        return $next($request);
    }
}
