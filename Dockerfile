FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive \
    INSTALL_DIR=/root/smb_scheduler_install \
    DATA_DIR=/data \
    WEB_ROOT=/var/www/html

# i386 для 32-битных зависимостей + Apache
RUN dpkg --add-architecture i386 \
 && apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates wget curl tar bash \
      apache2 \
      lib32z1 lib32z1-dev \
      libgssapi-krb5-2:i386 \
    && rm -rf /var/lib/apt/lists/*

# Каталоги
RUN mkdir -p "$DATA_DIR" "$WEB_ROOT"

# Тянем архив (кэш слоя). При старте проверим/докачаем при необходимости.
ADD http://dbltek.com/update/smb_scheduler_install-latest.tar.gz /tmp/smb_scheduler_install-latest.tar.gz

# Скрипт запуска
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Порты
EXPOSE 80/tcp 56012/tcp 56011/udp

# Том под данные/флаг установки
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s --retries=10 CMD curl -fsS http://127.0.0.1/smb_scheduler || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["run"]
