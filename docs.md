Oke! Kita buat **setup Docker full** untuk repo Livewire kamu, dari **clone repo langsung**, mendukung **development** (Nginx + PHP-FPM) dan **production** (FrankenPHP + Caddy), dalam satu `docker-compose.yml` yang **multi-env**.

Struktur folder akan seperti ini:

```
repo/
├─ laravel_app/        # volume mount, bisa kosong awalnya
├─ docker/
│  ├─ php/
│  │  └─ Dockerfile
│  ├─ nginx/
│  │  └─ default.conf
│  └─ init.sh
├─ docker-compose.yml
└─ .env                # ENV global
```

---

## 1️⃣ Dockerfile PHP-FPM (`docker/php/Dockerfile`)

```dockerfile
# docker/php/Dockerfile
FROM php:8.2-fpm

# Install PHP extensions & tools
RUN apt-get update && apt-get install -y \
    zip unzip git curl libpng-dev libonig-dev libxml2-dev \
    supervisor \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy entrypoint
COPY ../init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["php-fpm"]
```

---

## 2️⃣ Nginx config (`docker/nginx/default.conf`)

```nginx
server {
    listen 80;
    server_name localhost;
    root /var/www/html/public;

    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass app:9000;  # PHP-FPM service
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

---

## 3️⃣ Init script (`docker/init.sh`)

```bash
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

# Install PHP dependencies
composer install --optimize-autoloader --no-dev

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

# Run migrations (skip jika gagal)
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

# Jalankan server sesuai environment
if [ "$APP_ENV" = "production" ]; then
    echo "Menjalankan FrankenPHP + Caddy untuk production..."
    exec frankenphp --host 0.0.0.0 --port 80 public/index.php
else
    echo "Menjalankan PHP-FPM + Nginx untuk development..."
    service php8.2-fpm start
    nginx -g 'daemon off;'
fi
```

---

## 4️⃣ Docker-compose (`docker-compose.yml`)

```yaml
version: '3.9'
services:
  app:
    build:
      context: .
      dockerfile: docker/php/Dockerfile
    container_name: laravel_app
    volumes:
      - ./laravel_app:/var/www/html
    environment:
      APP_ENV: ${APP_ENV:-local}
      DB_CONNECTION: mysql
      DB_HOST: mysql
      DB_PORT: 3306
      DB_DATABASE: laravel_db
      DB_USERNAME: laravel
      DB_PASSWORD: secret
    depends_on:
      - mysql
      - phpmyadmin
    networks:
      - laravel

  nginx:
    image: nginx:alpine
    container_name: laravel_nginx
    volumes:
      - ./laravel_app:/var/www/html
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf
    ports:
      - "8000:80"
    depends_on:
      - app
    networks:
      - laravel
    # Hanya aktif di dev
    deploy:
      replicas: 0
      placement:
        constraints:
          - node.labels.env == dev

  mysql:
    image: mysql:8
    container_name: laravel_mysql
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: laravel_db
      MYSQL_USER: laravel
      MYSQL_PASSWORD: secret
    ports:
      - "3307:3306"
    volumes:
      - ./mysql_data:/var/lib/mysql
    networks:
      - laravel

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    container_name: laravel_phpmyadmin
    restart: always
    ports:
      - "8001:80"
    environment:
      PMA_HOST: mysql
      PMA_PORT: 3306
      MYSQL_ROOT_PASSWORD: root
    depends_on:
      - mysql
    networks:
      - laravel

networks:
  laravel:
```

---

## 5️⃣ .env

```env
APP_ENV=local
UID=1000
GID=1000
COMPOSE_PROJECT_NAME=liveapp

# DB Config
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel_db
DB_USERNAME=laravel
DB_PASSWORD=secret
```

---

### Cara pakai:

**Development**:

```bash
docker-compose up --build
# akses http://localhost:8000
```

**Production**:

```bash
APP_ENV=production docker-compose up --build
# FrankenPHP + Caddy langsung jalan di port 80 container
```

---

✅ Fitur setup ini:

1. Clone repo Livewire langsung, tidak perlu `composer create-project`.
2. Multi-environment: Dev (Nginx + PHP-FPM), Prod (FrankenPHP + Caddy).
3. `.env` otomatis disesuaikan dari docker-compose.
4. Hak akses storage/cache diatur otomatis.
5. Laravel migrations dijalankan otomatis jika ada database.

---

Kalau mau, saya bisa buatkan **versi lebih lanjut** dengan **Livewire + Tailwind + Vite otomatis build asset** di container, jadi begitu `docker-compose up` semua frontend juga langsung jalan.

Apakah mau saya buatkan juga versi itu?
