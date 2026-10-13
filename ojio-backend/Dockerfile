FROM php:8.4-cli-alpine

# Install system dependencies & PHP extensions
RUN apk add --no-cache \
    zip \
    unzip \
    git \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \
    && docker-php-ext-install pdo pdo_mysql mbstring zip bcmath

# Ensure PHP CLI populates $_ENV from Docker environment variables
RUN echo "variables_order = \"EGPCS\"" > /usr/local/etc/php/conf.d/variables_order.ini

# Copy Composer from official image
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Copy project files
COPY . .

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts --ignore-platform-req=php+

# Ensure directories and permissions exist
RUN mkdir -p storage/framework/cache/data \
    && mkdir -p storage/framework/sessions \
    && mkdir -p storage/framework/views \
    && mkdir -p storage/logs \
    && mkdir -p bootstrap/cache \
    && chmod -R 777 storage bootstrap/cache

ENV PORT=8080
EXPOSE 8080

# Run native PHP server with router script directly on Railway PORT (never on port 0)
CMD ["sh", "-c", "exec php -d variables_order=EGPCS -S 0.0.0.0:${PORT:-8080} server.php"]
