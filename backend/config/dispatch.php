<?php

return [
    /*
    | How long (seconds) a driver has to accept an offer before it expires and
    | the order is re-dispatched to the next nearest driver.
    */
    'offer_ttl' => (int) env('DISPATCH_OFFER_TTL', 45),

    /*
    | Maximum distance (km) a candidate driver may be from the pickup point.
    | The closed-area system already scopes drivers to the customer's area, so
    | this is a soft cap; drivers without a known location are still eligible.
    */
    'radius_km' => (float) env('DISPATCH_RADIUS_KM', 50),

    /*
    | Consider a driver's GPS "fresh" only if reported within this many minutes.
    | Stale-location drivers are ranked after fresh ones but still eligible.
    */
    'location_fresh_minutes' => (int) env('DISPATCH_LOCATION_FRESH_MINUTES', 10),
];
