#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/root/smb_scheduler_install"
ARCHIVE="/tmp/smb_scheduler_install-latest.tar.gz"
DATA_DIR="/data"
FLAG_FILE="${DATA_DIR}/.installed"
WEB_ROOT="/var/www/html"
BIN_DIR="/usr/local/smb_scheduler"

log() { echo "[smb-docker] $*"; }

start_mysql() {
  log "Инициализирую/запускаю MariaDB…"
  mkdir -p /run/mysqld
  chown -R mysql:mysql /run/mysqld /var/lib/mysql || true

  # Инициализация БД при первом запуске
  if [[ ! -d /var/lib/mysql/mysql ]]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null
  fi

  # Запуск демона (локально, без внешнего доступа)
  mariadbd --user=mysql \
           --datadir=/var/lib/mysql \
           --bind-address=127.0.0.1 \
           --skip-name-resolve \
           --skip-networking=0 \
           --pid-file=/run/mysqld/mysqld.pid &
  # Ожидание готовности
  for i in {1..60}; do
    if mysqladmin ping --silent ; then
      log "MariaDB готова."
      return
    fi
    sleep 1
  done
  log "ОШИБКА: MariaDB не поднялась."
  exit 1
}

install_if_needed() {
  if [[ -f "${FLAG_FILE}" ]]; then
    log "Установка уже выполнена — пропускаю."
    return
  fi

  # Подстрахуемся: докачаем архив если надо
  if [[ ! -s "${ARCHIVE}" ]]; then
    log "Скачиваю инсталлятор…"
    wget -O "${ARCHIVE}" "http://dbltek.com/update/smb_scheduler_install-latest.tar.gz"
  fi

  log "Распаковываю инсталлятор…"
  mkdir -p /root
  tar -xvzf "${ARCHIVE}" -C /root

  if [[ ! -d "${INSTALL_DIR}" ]]; then
    log "ОШИБКА: нет каталога ${INSTALL_DIR} после распаковки."
    exit 1
  fi

  # MariaDB нужна для шага 'Import Goip Databases'
  start_mysql

  # Путь конфигов Apache по умолчанию — дадим инсталлятору.
  mkdir -p /etc/apache2/sites-enabled

  log "Запускаю установку (non-interactive, пустые ответы)…"
  cd "${INSTALL_DIR}"
  chmod +x ./smb_scheduler_install.sh || true
  yes '' | bash ./smb_scheduler_install.sh

  log "Установка завершена. Ставлю флаг."
  touch "${FLAG_FILE}"

  # Симлинк UI если веб положили в /var/www/smb_scheduler
  if [[ -d "/var/www/smb_scheduler" && ! -e "${WEB_ROOT}/smb_scheduler" ]]; then
    ln -s "/var/www/smb_scheduler" "${WEB_ROOT}/smb_scheduler" || true
  fi
}

start_sim_daemons() {
  # Если инсталлятор положил бинарники — запустим их.
  if [[ -d "${BIN_DIR}" ]]; then
    for bin in smb_scheduler smb_watchd xchanged; do
      if [[ -x "${BIN_DIR}/${bin}" ]]; then
        log "Стартую ${bin}…"
        "${BIN_DIR}/${bin}" || true
      fi
    done
  fi
}

start_web() {
  if command -v apache2ctl >/dev/null 2>&1; then
    log "Запускаю Apache в foreground."
    # Запуск SIM-демонов перед веб-сервером (если нужно открыть 56011/56012)
    start_sim_daemons
    exec apache2ctl -D FOREGROUND
  fi

  if command -v busybox >/dev/null 2>&1; then
    log "Apache не найден. Fallback httpd на :80, корень=${WEB_ROOT}"
    start_sim_daemons
    exec busybox httpd -f -p 0.0.0.0:80 -h "${WEB_ROOT}"
  fi

  log "Нет веб-сервера. Оставляю контейнер живым."
  start_sim_daemons
  exec tail -f /dev/null
}

case "${1:-run}" in
  run) install_if_needed; start_web ;;
  bash|sh) exec "$@" ;;
  *) exec "$@" ;;
esac
