FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive \
    INSTALL_DIR=/root/smb_scheduler_install \
    DATA_DIR=/data

# 32-bit зависимости + mysql-клиент + psmisc (killall) + wget/tar/curl
RUN dpkg --add-architecture i386 \
 && apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates wget curl tar bash psmisc \
      mariadb-client \
      lib32z1 lib32z1-dev \
      libgssapi-krb5-2:i386 \
 && rm -rf /var/lib/apt/lists/*

# Имитация наличия apache-конф. пути, чтобы инсталлятор не падал
RUN mkdir -p /etc/apache2/sites-enabled /var/www/html

# Кэш инсталлятора (необязательно, но ускоряет)
ADD http://dbltek.com/update/smb_scheduler_install-latest.tar.gz /tmp/smb_scheduler_install-latest.tar.gz

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/data", "/var/www/html"]

EXPOSE 56012/tcp 56011/udp
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["run"]
