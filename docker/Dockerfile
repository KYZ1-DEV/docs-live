# docker/php/Dockerfile
FROM php:8.2-fpm

# Install PHP extensions & tools
RUN apt-get update && apt-get install -y \
    zip unzip git curl libpng-dev libonig-dev libxml2-dev \
    supervisor \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Aktifkan mod_rewrite untuk Laravel
RUN a2enmod rewrite

# Copy entrypoint
COPY docker/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["php-fpm"]
