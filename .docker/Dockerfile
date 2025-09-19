FROM mattrayner/lamp:1804-php5-base


# Кладём инсталлятор 1(вы загрузите в гит именно таким именем)
COPY .docker/smb_scheduler_install-latest.tar.gz /root/


# Служебные скрипты
COPY .docker/smbinit.sh /smbinit.sh
COPY .docker/run.sh /run.sh


RUN chmod +x /smbinit.sh /run.sh \
&& mkdir -p /root/smb_scheduler_install \
&& tar -xvzf /root/smb_scheduler_install-latest.tar.gz -C /root \
&& sed -i 's/\r$//' /smbinit.sh /run.sh


# Внутри контейнера веб слушает 80; наружу вынесем 8080 через compose
EXPOSE 80
