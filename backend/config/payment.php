<?php

return [
    /*
    | Active gateway: "fake" (default — deterministic, verifiable without any
    | external account) or "midtrans" (real). Set PAYMENT_GATEWAY=midtrans in
    | production once the account is provisioned.
    */
    'gateway' => env('PAYMENT_GATEWAY', 'fake'),

    /*
    | Platform commission taken from each trip fare (matches the admin dashboard).
    */
    'commission_rate' => (float) env('PLATFORM_COMMISSION_RATE', 0.20),

    'fake' => [
        // When true the fake charge is confirmed instantly (keeps the demo/QRIS
        // flow one-tap). Set false to exercise the pending → webhook path.
        'auto_confirm' => (bool) env('PAYMENT_FAKE_AUTO_CONFIRM', true),
        'webhook_secret' => env('PAYMENT_FAKE_WEBHOOK_SECRET', 'fake-secret'),
    ],

    'midtrans' => [
        'server_key' => env('MIDTRANS_SERVER_KEY'),
        'client_key' => env('MIDTRANS_CLIENT_KEY'),
        'production' => (bool) env('MIDTRANS_PRODUCTION', false),
        'base_url' => env('MIDTRANS_PRODUCTION', false)
            ? 'https://api.midtrans.com'
            : 'https://api.sandbox.midtrans.com',
    ],

    'disbursement' => [
        // "fake" (auto-success) or "xendit".
        'provider' => env('DISBURSEMENT_PROVIDER', 'fake'),
        'xendit_secret' => env('XENDIT_SECRET_KEY'),
    ],
];
