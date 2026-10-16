# Guide Déploiement & Optimisation - Espace Locataire

## 🚀 Déploiement

### Pre-Deployment Checklist

```bash
# 1. Vérifier les dépendances
composer validate
composer check-platform-reqs

# 2. Vérifier la configuration
php bin/console lint:container
php bin/console lint:yaml config/

# 3. Vérifier les entités
php bin/console doctrine:schema:validate

# 4. Nettoyer le cache
php bin/console cache:clear --env=prod

# 5. Dump les variables d'env
composer dump-env prod

# 6. Compiler les assets
php bin/console asset-map:compile
```

### Production Configuration

#### .env.local.php (après dump-env)
```php
<?php
return [
    'APP_ENV' => 'prod',
    'APP_SECRET' => 'your-secret-key-here-32-chars-min',
    'DATABASE_URL' => 'mysql://user:password@db-host:3306/homeconnect?serverVersion=8.0&charset=utf8mb4',
    'MAILER_DSN' => 'smtp://smtp-host:587?encryption=tls&username=user&password=pass',
    'TRUSTED_PROXIES' => '127.0.0.1',
    'TRUSTED_HEADERS' => 'X-Forwarded-For,X-Forwarded-Proto,X-Forwarded-Host,CF-Connecting-IP',
];
```

#### config/packages/doctrine.yaml (optimization)
```yaml
doctrine:
  dbal:
    url: '%env(DATABASE_URL)%'
    options:
      1002: "SET NAMES utf8mb4"
    
  orm:
    auto_generate_proxy_classes: false
    proxy_dir: '%kernel.cache_dir%/doctrine/orm/proxies'
    enable_lazy_ghost_objects: true
    
    metadata_cache_driver:
      type: pool
      pool: doctrine.system_cache_pool
    
    result_cache_driver:
      type: pool
      pool: doctrine.result_cache_pool
    
    query_cache_driver:
      type: pool
      pool: doctrine.query_cache_pool
```

#### config/packages/cache.yaml (Redis)
```yaml
framework:
  cache:
    default_redis_provider: 'redis://redis-host:6379'
    pools:
      doctrine.result_cache_pool:
        adapter: cache.adapter.redis
      doctrine.query_cache_pool:
        adapter: cache.adapter.redis
      doctrine.system_cache_pool:
        adapter: cache.adapter.redis
```

### Docker Deployment

#### docker-compose.yml (production)
```yaml
version: '3.8'
services:
  app:
    image: homeconnect:latest
    build:
      context: .
      dockerfile: Dockerfile.prod
    environment:
      APP_ENV: prod
      DATABASE_URL: 'mysql://app:password@db:3306/homeconnect'
    depends_on:
      - db
      - redis
    ports:
      - "8000:80"
    volumes:
      - ./var/log:/app/var/log
    restart: unless-stopped

  db:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: homeconnect
      MYSQL_ROOT_PASSWORD: root
      MYSQL_PASSWORD: password
      MYSQL_USER: app
    volumes:
      - db-data:/var/lib/mysql
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./public:/app/public:ro
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app
    restart: unless-stopped

volumes:
  db-data:
  redis-data:
```

#### Dockerfile.prod
```dockerfile
FROM php:8.2-fpm-alpine

RUN apk add --no-cache \
    postgresql-dev \
    mysql-client \
    libpq-dev \
    git \
    curl \
    unzip

RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    opcache \
    apcu

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/

WORKDIR /app

COPY . .

RUN composer install --no-dev --optimize-autoloader

RUN php bin/console cache:warmup --env=prod

EXPOSE 9000

CMD ["php-fpm"]
```

## ⚡ Optimisation Performance

### 1. Database Optimization

#### Indexes
```sql
-- Favorites
CREATE INDEX idx_favorite_locataire ON favorite(locataire_id);
CREATE INDEX idx_favorite_property ON favorite(property_id);
CREATE UNIQUE INDEX uk_favorite_locataire_property ON favorite(locataire_id, property_id);

-- Posts
CREATE INDEX idx_post_author ON post(author_id);
CREATE INDEX idx_post_category ON post(category);
CREATE INDEX idx_post_created ON post(created_at DESC);

-- Comments
CREATE INDEX idx_comment_post ON post_comment(post_id);
CREATE INDEX idx_comment_author ON post_comment(author_id);

-- Reports
CREATE INDEX idx_report_reporter ON community_report(reporter_id);
CREATE INDEX idx_report_status ON community_report(status);
CREATE INDEX idx_report_priority ON community_report(priority);

-- Reviews
CREATE INDEX idx_review_target ON review(target_user_id);
CREATE INDEX idx_review_author ON review(author_id);
```

#### Query Optimization
```php
// ❌ Bad: N+1 queries
$posts = $postRepo->findAll();
foreach ($posts as $post) {
    echo $post->getAuthor()->getFullName(); // Extra query per post
}

// ✅ Good: Join
$posts = $postRepo->createQueryBuilder('p')
    ->leftJoin('p.author', 'a')
    ->addSelect('a')
    ->getQuery()
    ->getResult();
```

### 2. Caching Strategy

#### Result Caching
```php
// Cache reviews calculations
public function calculateAverageRating(int $userId): float
{
    $cacheKey = "user_{$userId}_average_rating";
    
    $cached = $this->cache->getItem($cacheKey);
    if ($cached->isHit()) {
        return $cached->get();
    }
    
    $rating = $this->createQueryBuilder('r')
        ->select('AVG(r.rating)')
        ->where('r.targetUser = :user')
        ->setParameter('user', $userId)
        ->getQuery()
        ->getSingleScalarResult();
    
    $cached->set($rating)->expiresAfter(3600); // 1 hour
    $this->cache->save($cached);
    
    return (float) $rating;
}
```

### 3. Asset Optimization

#### CSS/JS Minification
```bash
# Build assets for production
php bin/console asset-map:compile

# Verify assets compiled
ls -la public/assets/
```

#### Image Optimization
```bash
# Install ImageMagick
apt-get install imagemagick

# Generate thumbnails
convert property-image.jpg -resize 800x600 -quality 85 property-thumb.jpg
```

### 4. Server Configuration

#### PHP-FPM (php.ini)
```ini
[PHP]
upload_max_filesize = 50M
post_max_size = 50M
max_execution_time = 60
memory_limit = 256M
opcache.enable = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0
opcache.revalidate_freq = 60
apc.enabled = 1
apc.memory_consumption = 256M
```

#### Nginx Configuration
```nginx
upstream php_fpm {
    server app:9000;
}

server {
    listen 80;
    server_name homeconnect.cm;

    root /app/public;
    index index.php;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css text/javascript application/json;
    gzip_min_length 1000;

    # Caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # PHP handling
    location ~ \.php$ {
        fastcgi_pass php_fpm;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Deny access to sensitive files
    location ~ /\. { deny all; }
    location ~ ~$ { deny all; }
}
```

## 🔒 Security Hardening

### 1. Headers Security
```php
// config/packages/framework.yaml
framework:
    http_client:
        max_redirects: 5
    trusted_hosts: ['^homeconnect\.cm$']

// Kernel.php
public function boot(): void
{
    parent::boot();
    
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: SAMEORIGIN');
    header('X-XSS-Protection: 1; mode=block');
    header('Strict-Transport-Security: max-age=31536000; includeSubDomains');
}
```

### 2. Rate Limiting
```yaml
# config/packages/rate_limiter.yaml
framework:
  rate_limiter:
    login_limiter:
      strategy: sliding_window
      limit: 5
      interval: '15 minutes'
    
    api_limiter:
      strategy: token_bucket
      limit: 100
      interval: '1 minute'
```

### 3. DDoS Protection
```nginx
# Nginx rate limiting
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=search:10m rate=5r/s;

location /locataire/search {
    limit_req zone=search burst=10;
    proxy_pass http://php_fpm;
}

location / {
    limit_req zone=general burst=20;
    proxy_pass http://php_fpm;
}
```

## 📊 Monitoring

### 1. Error Logging
```yaml
# config/packages/monolog.yaml
monolog:
  handlers:
    main:
      type: fingers_crossed
      action_level: error
      handler: nested
      excluded_404s:
        - ^/
    
    nested:
      type: stream
      path: "%kernel.logs_dir%/%kernel.environment%.log"
      level: debug
    
    console:
      type: console
      process_psr_3_messages: false
```

### 2. Performance Monitoring
```bash
# APCu stats
php -r "print_r(apcu_cache_info(false));"

# Query logging
SYMFONY_DEBUG_MODE=1 php bin/console cache:clear
```

### 3. Health Check Endpoint
```php
// src/Controller/HealthController.php
public function check(Connection $connection): Response
{
    try {
        $connection->executeQuery('SELECT 1');
        return new JsonResponse(['status' => 'ok']);
    } catch (\Exception $e) {
        return new JsonResponse(['status' => 'error'], 500);
    }
}
```

## 📈 Scaling

### 1. Database Replication
```yaml
# Master-Slave setup
- Production MySQL Master (writes)
- Read Replicas (reads)
- Configure Doctrine to use replicas for reads
```

### 2. CDN Integration
```php
// Use CDN for static assets
public function getAssetUrl(string $path): string
{
    if ($this->env === 'prod') {
        return "https://cdn.homeconnect.cm/assets/{$path}";
    }
    return "/assets/{$path}";
}
```

### 3. Load Balancing
```
              ┌─ App Server 1
    Router ───┼─ App Server 2
              └─ App Server 3
                     ↓
                  DB Master
                     ↓
                  DB Replica
```

## ✅ Production Checklist

- [ ] .env.local.php configured
- [ ] DATABASE_URL set correctly
- [ ] MAILER_DSN configured
- [ ] APP_SECRET changed (32+ chars)
- [ ] Cache warmed: `cache:clear --env=prod`
- [ ] Assets compiled: `asset-map:compile`
- [ ] Migrations executed: `doctrine:migrations:migrate`
- [ ] Logs directory writable: `var/log/`
- [ ] Uploads directory writable: `public/uploads/`
- [ ] SSL certificate installed
- [ ] Rate limiting configured
- [ ] Monitoring setup
- [ ] Backups configured
- [ ] Security headers verified
- [ ] Error pages customized

## 🔄 Maintenance

### Regular Tasks

```bash
# Weekly
php bin/console doctrine:migrations:status
php bin/console cache:warmup

# Monthly
composer update
php bin/console security:check
php bin/console lint:container

# Quarterly
php bin/console doctrine:schema:validate
php bin/console debug:router | wc -l
```

---

**Version**: 1.0  
**Date**: 29 Avril 2026  
**Framework**: Symfony 7.2.9
