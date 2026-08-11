<?php

namespace App\Providers;

use App\Services\Payment\FakePaymentGateway;
use App\Services\Payment\MidtransGateway;
use App\Services\Payment\PaymentGateway;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Bind the active payment gateway (Phase 3). Defaults to the fake gateway
        // so the app runs without any external account; set PAYMENT_GATEWAY=midtrans
        // in production.
        $this->app->bind(PaymentGateway::class, fn () => match (config('payment.gateway')) {
            'midtrans' => new MidtransGateway(),
            default => new FakePaymentGateway(),
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
