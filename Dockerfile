FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
# Рабочие директории
ENV INSTALL_DIR=/root/smb_scheduler_install \
    DATA_DIR=/data \
    WEB_ROOT=/var/www/html

# Базовые утилиты + fallback httpd и curl для healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates wget curl tar bash \
      busybox-static \
    && rm -rf /var/lib/apt/lists/*

# Создадим директории для данных/флагов
RUN mkdir -p "$DATA_DIR" "$WEB_ROOT"

# На всякий — заранее подтянем архив (кэш слоя), но устанавливать будем на старте
ADD http://dbltek.com/update/smb_scheduler_install-latest.tar.gz /tmp/smb_scheduler_install-latest.tar.gz

# Скопируем entrypoint и сделаем исполняемым
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Веб будет слушать 80 внутри контейнера
EXPOSE 80

# Пробросим данные (если инсталлятор запишет куда-то состояние)
VOLUME ["/data"]

# Healthcheck: проверяем, что UI отдает страницу
HEALTHCHECK --interval=30s --timeout=5s --retries=10 CMD curl -fsS http://127.0.0.1/smb_scheduler || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["run"]
