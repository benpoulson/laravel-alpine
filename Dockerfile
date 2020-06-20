FROM php:7.4-fpm-alpine
MAINTAINER Ben Poulson <benpoulson@protonmail.ch>

# Install dependencies
RUN apk --update add wget \
  curl \
  git \
  grep \
  nginx \
  build-base \
  autoconf \
  cyrus-sasl-dev \
  dpkg-dev \
  freetype-dev \
  icu-dev \
  libc-dev \
  libgsasl-dev \
  libjpeg-turbo-dev \
  libmcrypt-dev \
  libpng-dev \
  libxml2-dev \
  libzip-dev \
  oniguruma-dev \
  openssl-dev \
  supervisor \
  zlib-dev


# Install PHP modules
RUN docker-php-ext-install mysqli mbstring pdo pdo_mysql tokenizer xml opcache bcmath pcntl iconv zip intl gd soap
RUN pecl channel-update pecl.php.net && pecl install redis trader && docker-php-ext-enable redis trader

# Install Composer with prestissimo
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
 && php composer-setup.php --install-dir=/bin/ --filename=composer \
 && chmod +x /bin/composer \
 && rm -rf composer-setup.php \
 && composer global require hirak/prestissimo

# Clear out extra weight
RUN rm /var/cache/apk/* \
 && mkdir -p /var/www

# Setup PHP configs
RUN echo "date.timezone=UTC" >  /usr/local/etc/php/conf.d/system.ini \
&& echo 'log_errors_max_len = 9223372036854775807' >> /usr/local/etc/php/conf.d/system.ini \
&& echo "memory_limit = 512M;" >> /usr/local/etc/php/conf.d/uploads.ini \
&& echo "upload_max_filesize=128M" >> /usr/local/etc/php/conf.d/uploads.ini \
&& echo "post_max_size=128M" >> /usr/local/etc/php/conf.d/uploads.ini \
&& echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
&& echo "opcache.memory_consumption=512" >>/usr/local/etc/php/conf.d/opcache.ini \
&& echo "opcache.interned_strings_buffer=64" >> /usr/local/etc/php/conf.d/opcache.ini \
&& echo "opcache.max_accelerated_files=32531" >> /usr/local/etc/php/conf.d/opcache.ini \
&& sed -i 's/127.0.0.1:9000/0.0.0.0:9000/g' /usr/local/etc/php-fpm.d/www.conf \
&& sed -i 's/pm.max_children = 5/pm.max_children = 50/g' /usr/local/etc/php-fpm.d/www.conf \
&& sed -i 's/pm.start_servers = 2/pm.start_servers = 8/g' /usr/local/etc/php-fpm.d/www.conf \
&& sed -i 's/pm.min_spare_servers = 1/pm.min_spare_servers = 5/g' /usr/local/etc/php-fpm.d/www.conf \
&& sed -i 's/pm.max_spare_servers = 3/pm.max_spare_servers = 10/g' /usr/local/etc/php-fpm.d/www.conf \
&& echo '[global]' > /usr/local/etc/php-fpm.d/docker.conf \
&& echo 'error_log = /proc/self/fd/2' >> /usr/local/etc/php-fpm.d/docker.conf \
&& echo '[www]' >> /usr/local/etc/php-fpm.d/docker.conf \
&& echo 'access.log = /proc/self/fd/2' >> /usr/local/etc/php-fpm.d/docker.conf \
&& echo 'clear_env = no' >> /usr/local/etc/php-fpm.d/docker.conf \
&& echo 'catch_workers_output = yes' >> /usr/local/etc/php-fpm.d/docker.conf \
&& echo 'decorate_workers_output = no' >> /usr/local/etc/php-fpm.d/docker.conf

# Copy configurations
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.ini /etc/supervisor.d/laravel.ini

# Run
CMD php /var/www/artisan migrate && /usr/bin/supervisord -n -c /etc/supervisord.conf
