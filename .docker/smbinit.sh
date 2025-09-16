#!/bin/bash
set -e


# Запуск MySQL в фоне, ждём готовности, запускаем инсталлятор
/usr/bin/mysqld_safe > /dev/null 2>&1 &


RET=1
while [[ $RET -ne 0 ]]; do
echo "=> Ожидание старта MySQL"
sleep 5
mysql -uroot -e "status" > /dev/null 2>&1 || true
RET=$?
done


if [[ ! -d /var/www/html/smb_scheduler ]]; then
echo "=> Запуск установщика SMB Scheduler"
cd /root/smb_scheduler_install
chmod +x ./smb_scheduler_install.sh
./smb_scheduler_install.sh
echo "=> Установщик завершён"
else
echo "=> SMB Scheduler уже установлен, пропускаем"
fi


# Аккуратно останавливаем MySQL — далее его поднимет supervisord
mysqladmin -uroot shutdown || true