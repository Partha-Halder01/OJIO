#!/bin/sh
set -eu

# APP_KEY must be copied unchanged when importing Railway's encrypted records.
if [ -z "${APP_KEY:-}" ]; then
    echo "APP_KEY is required. Preserve the source key when importing existing data." >&2
    exit 1
fi

# Never migrate, seed, generate keys or delete data during container startup.
php artisan config:cache --no-interaction
php artisan route:cache --no-interaction
php artisan view:cache --no-interaction

exec docker-php-entrypoint "$@"
