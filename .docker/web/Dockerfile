FROM php:7.4-apache

# Включим mod_rewrite, положим vhost и корректный DocumentRoot
RUN a2enmod rewrite
COPY vhost.conf /etc/apache2/sites-available/000-default.conf

# Безопасные умолчания прав
RUN chown -R www-data:www-data /var/www && a2ensite 000-default

EXPOSE 80