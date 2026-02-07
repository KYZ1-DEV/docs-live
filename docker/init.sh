#!/bin/bash
set -e

APP_ENV=${APP_ENV:-local}
echo "Environment Laravel: $APP_ENV"

cd /var/www/html

# Clone repo jika folder kosong
if [ ! -f composer.json ]; then
    echo "Folder kosong, clone repo Livewire starter kit..."
    git clone https://github.com/KYZ1-DEV/stater-live.git .
else
    echo "Repo sudah ada, skip clone."
fi

# PHP dependencies
composer install --optimize-autoloader --no-dev

# Node dependencies & build
if [ -f package.json ]; then
    echo "Install Node dependencies & build assets..."
    npm install
    if [ "$APP_ENV" = "production" ]; then
        npm run build
    else
        npm run dev
    fi
fi

# Set environment DB
sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=${DB_CONNECTION}/" .env
sed -i "s/^#* *DB_HOST=.*/DB_HOST=${DB_HOST}/" .env
sed -i "s/^#* *DB_PORT=.*/DB_PORT=${DB_PORT:-3306}/" .env
sed -i "s/^#* *DB_DATABASE=.*/DB_DATABASE=${DB_DATABASE}/" .env
sed -i "s/^#* *DB_USERNAME=.*/DB_USERNAME=${DB_USERNAME}/" .env
sed -i "s/^#* *DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" .env

# Permissions
mkdir -p storage/logs bootstrap/cache
chmod -R 775 storage bootstrap/cache

# Migrate
php artisan migrate || echo "Migrasi gagal, mungkin belum siap"

# Cache Laravel
if [ "$APP_ENV" = "production" ]; then
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
else
    php artisan config:clear
    php artisan route:clear
    php artisan view:clear
    php artisan cache:clear
fi

# Jalankan server
if [ "$APP_ENV" = "production" ]; then
    echo "Menjalankan FrankenPHP + Caddy..."
    exec frankenphp --host 0.0.0.0 --port 80 public/index.php
else
    echo "Menjalankan PHP-FPM + Nginx..."
    service php8.2-fpm start
    nginx -g 'daemon off;'
fi
