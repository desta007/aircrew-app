<?php

return [
    /*
    | Shared secret required by the admin monitoring endpoints. When empty the
    | endpoints stay open (local/demo). Set ADMIN_API_TOKEN in production and send
    | it as the `X-Admin-Token` header from the dashboard.
    */
    'token' => env('ADMIN_API_TOKEN'),
];
