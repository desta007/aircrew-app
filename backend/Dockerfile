# AirCrew backend — Laravel 13 (PHP 8.3) for Railway.
# Deterministic build: installs the PostgreSQL PDO driver, Composer deps, then
# runs migrations and serves the app on Railway's injected $PORT.
FROM php:8.3-cli

# System libraries + PostgreSQL PDO extension.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev unzip git \
    && docker-php-ext-install pdo pdo_pgsql \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Composer (copied from the official image).
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . .

RUN composer install --no-dev --optimize-autoloader --no-interaction \
    && chmod -R 775 storage bootstrap/cache

# Railway injects $PORT at runtime; default for local `docker run`.
ENV PORT=8000
EXPOSE 8000

# Run pending migrations (idempotent, non-destructive) then start the app.
# Seed the demo data once from the Railway service shell (see DEPLOY-RAILWAY.md).
CMD php artisan migrate --force \
    && php artisan config:clear \
    && php artisan serve --host 0.0.0.0 --port "${PORT}"
