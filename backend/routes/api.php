<?php

use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Controllers\Api\MitraController;
use App\Http\Controllers\Api\WithdrawalController;
use Illuminate\Support\Facades\Route;

Route::get('/ping', fn () => response()->json(['app' => 'AirCrew API', 'status' => 'ok']));

// ---------- Auth (login terhadap database, keluarkan token Sanctum) ----------
Route::post('/auth/customer/login', [AuthController::class, 'customerLogin']);
Route::post('/auth/mitra/login', [AuthController::class, 'mitraLogin']);
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);
});

// ---------- Mitra Driver app (butuh token) ----------
Route::middleware('auth:sanctum')->prefix('mitra')->group(function () {
    Route::get('/me', [MitraController::class, 'me']);
    Route::post('/online', [MitraController::class, 'toggleOnline']);
    Route::get('/incoming', [MitraController::class, 'incoming']);
    Route::post('/orders/{code}/accept', [MitraController::class, 'accept']);
    Route::post('/orders/{code}/reject', [MitraController::class, 'reject']);
    Route::post('/orders/{code}/advance', [MitraController::class, 'advance']);
    Route::post('/orders/{code}/complete', [MitraController::class, 'complete']);
    Route::post('/orders/{code}/rate', [MitraController::class, 'rate']);
    Route::get('/orders', [MitraController::class, 'orderHistory']);
    Route::get('/pendapatan', [MitraController::class, 'pendapatan']);
    Route::get('/withdrawals', [WithdrawalController::class, 'index']);
    Route::post('/withdrawals', [WithdrawalController::class, 'store']);
});

// ---------- Customer (Crew) app (butuh token) ----------
Route::middleware('auth:sanctum')->prefix('customer')->group(function () {
    Route::get('/me', [CustomerController::class, 'me']);
    Route::get('/drivers', [CustomerController::class, 'drivers']);
    Route::post('/orders', [CustomerController::class, 'storeOrder']);
    Route::get('/orders', [CustomerController::class, 'orderHistory']);
    Route::get('/orders/{code}', [CustomerController::class, 'showOrder']);
    Route::post('/orders/{code}/rate', [CustomerController::class, 'rateOrder']);
    Route::get('/invoices', [InvoiceController::class, 'index']);
    Route::get('/invoices/{code}', [InvoiceController::class, 'show']);
    Route::post('/invoices/{code}/pay', [InvoiceController::class, 'pay']);
});

// ---------- Admin dashboard (publik untuk demo monitoring) ----------
Route::prefix('admin')->group(function () {
    Route::get('/dashboard', [AdminController::class, 'dashboard']);
    Route::get('/areas', [AdminController::class, 'areas']);
    Route::get('/orders', [AdminController::class, 'orders']);
    Route::get('/drivers', [AdminController::class, 'drivers']);
    Route::get('/customers', [AdminController::class, 'customers']);
    Route::get('/withdrawals', [AdminController::class, 'withdrawals']);
    Route::get('/keuangan', [AdminController::class, 'keuangan']);
});
