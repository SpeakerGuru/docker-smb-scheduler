#!/bin/bash
set -e


VOLUME_HOME="/var/lib/mysql"


# Значения по умолчанию для лимитов загрузки файлов
: "${PHP_UPLOAD_MAX_FILESIZE:=64M}"
: "${PHP_POST_MAX_SIZE:=64M}"


# Определяем путь к php.ini
if [ -e /etc/php/5.6/apache2/php.ini ]; then
PHPCONF=/etc/php/5.6/apache2/php.ini
elif [ -e /etc/php/7.2/apache2/php.ini ]; then
PHPCONF=/etc/php/7.2/apache2/php.ini
else
PHPCONF=/etc/php/8.1/apache2/php.ini
fi


# Тюним php.ini
sed -ri -e "s/^upload_max_filesize.*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" \
-e "s/^post_max_size.*/post_max_size = ${PHP_POST_MAX_SIZE}/" "$PHPCONF"


# Привилегии и группы
sed -i "s/export APACHE_RUN_GROUP=www-data/export APACHE_RUN_GROUP=staff/" /etc/apache2/envvars || true


# Симлинк /app → /var/www/html, если базовый образ его использует
if [ -n "$APACHE_ROOT" ]; then
rm -f /var/www/html && ln -s "/app/${APACHE_ROOT}" /var/www/html
fi


# Каталоги для сокета mysql
mkdir -p /var/run/mysqld


# Права для Apache/PHP
chown -R www-data:staff /var/www || true
chown -R www-data:staff /app || true
chown -R www-data:staff /var/lib/mysql /var/run/mysqld
chmod -R 770 /var/lib/mysql /var/run/mysqld


# MySQL: слушать на всех интерфейсах и работать под www-data
sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf || true
sed -i "s/^user.*/user = www-data/" /etc/mysql/my.cnf || true


# Если том пустой — инициализируем MySQL
if [[ ! -d "$VOLUME_HOME/mysql" ]]; then
echo "=> Пустой том MySQL обнаружен, инициализируем"
mysqld --initialize-insecure > /dev/null 2>&1 || mysql_install_db > /dev/null 2>&1
echo "=> Инициализация завершена"
/create_mysql_users.sh || true
else
echo "=> Используем существующий том MySQL"
fi


# Первая установка SMB Scheduler (по наличию директории)
if [[ ! -d /var/www/html/smb_scheduler ]]; then
/smbinit.sh
fi


# Запуск процессов под supervisord базового образа
exec supervisord -n