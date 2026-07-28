<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Driver;
use App\Support\Present;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    /** Customer (crew) login → issues a Sanctum bearer token. */
    public function customerLogin(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|string',
            'password' => 'required|string',
        ]);

        $customer = Customer::with('area')
            ->where('email', $data['email'])
            ->orWhere('code', $data['email'])
            ->first();

        if (! $customer || ! Hash::check($data['password'], (string) $customer->password)) {
            return response()->json(['message' => 'Email atau password salah.'], 401);
        }

        $token = $customer->createToken('customer-app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'role' => 'customer',
            'customer' => Present::customer($customer),
        ]);
    }

    /** Mitra (driver) login → issues a Sanctum bearer token. */
    public function mitraLogin(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|string',
            'password' => 'required|string',
        ]);

        $driver = Driver::with('area')
            ->where('email', $data['email'])
            ->orWhere('code', $data['email'])
            ->first();

        if (! $driver || ! Hash::check($data['password'], (string) $driver->password)) {
            return response()->json(['message' => 'Email atau password salah.'], 401);
        }

        $token = $driver->createToken('mitra-app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'role' => 'mitra',
            'driver' => Present::driver($driver),
        ]);
    }

    /** Return the currently authenticated user (driver or customer). */
    public function me(Request $request)
    {
        $user = $request->user();
        if ($user instanceof Driver) {
            return response()->json(['role' => 'mitra', 'driver' => Present::driver($user->load('area'))]);
        }
        if ($user instanceof Customer) {
            return response()->json(['role' => 'customer', 'customer' => Present::customer($user->load('area'))]);
        }
        return response()->json(['message' => 'Unauthenticated.'], 401);
    }

    /** Revoke the token used for the current request. */
    public function logout(Request $request)
    {
        $request->user()?->currentAccessToken()?->delete();
        return response()->json(['ok' => true]);
    }
}
