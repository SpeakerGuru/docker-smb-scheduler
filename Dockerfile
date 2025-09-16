FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive \
    INSTALL_DIR=/root/smb_scheduler_install \
    DATA_DIR=/data \
    WEB_ROOT=/var/www/html

# 32-bit зависимости, Apache, MariaDB, и утилиты
RUN dpkg --add-architecture i386 \
 && apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates wget curl tar bash \
      apache2 psmisc \
      mariadb-server mariadb-client \
      lib32z1 lib32z1-dev \
      libgssapi-krb5-2:i386 \
    && rm -rf /var/lib/apt/lists/*

# Директории
RUN mkdir -p "$DATA_DIR" "$WEB_ROOT" /etc/apache2/sites-enabled

# Кэшируем архив (инсталлятор всё равно запускается на старте)
ADD http://dbltek.com/update/smb_scheduler_install-latest.tar.gz /tmp/smb_scheduler_install-latest.tar.gz

# Скрипт запуска
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Порты (UI и SIM Server)
EXPOSE 80/tcp 56012/tcp 56011/udp

# Том(а)
VOLUME ["/data", "/var/lib/mysql"]

# Healthcheck только по UI (SIM-порт можно добавить отдельно при необходимости)
HEALTHCHECK --interval=30s --timeout=5s --retries=10 CMD curl -fsS http://127.0.0.1/smb_scheduler || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["run"]
