#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/root/smb_scheduler_install"
ARCHIVE="/tmp/smb_scheduler_install-latest.tar.gz"
DATA_DIR="/data"
FLAG_FILE="${DATA_DIR}/.installed"
WEB_ROOT="/var/www/html"

log() { echo "[smb-docker] $*"; }

install_if_needed() {
  if [[ -f "${FLAG_FILE}" ]]; then
    log "Установка уже выполнена ранее — пропускаю."
    return
  fi

  log "Распаковываю инсталлятор…"
  mkdir -p /root
  tar -xvzf "${ARCHIVE}" -C /root

  if [[ ! -d "${INSTALL_DIR}" ]]; then
    log "ОШИБКА: каталог ${INSTALL_DIR} не найден после распаковки."
    exit 1
  fi

  log "Запускаю установку…"
  cd "${INSTALL_DIR}"
  chmod +x ./smb_scheduler_install.sh || true
  # Некоторые инсталляторы требуют интерактивность — пробуем в простом режиме
  bash ./smb_scheduler_install.sh

  log "Установка завершена. Ставлю флаг."
  touch "${FLAG_FILE}"

  # На всякий случай, если веб положили в нестандартное место — создадим алиас
  if [[ -d "/var/www/smb_scheduler" && ! -e "${WEB_ROOT}/smb_scheduler" ]]; then
    ln -s "/var/www/smb_scheduler" "${WEB_ROOT}/smb_scheduler" || true
  fi
}

start_web() {
  # Попытка запустить популярные веб-сервера, если они появились после установки.
  if command -v nginx >/dev/null 2>&1; then
    log "Обнаружен nginx — запускаю в foreground."
    exec nginx -g 'daemon off;'
  fi

  if command -v apache2ctl >/dev/null 2>&1; then
    log "Обнаружен apache — запускаю в foreground."
    exec apache2ctl -D FOREGROUND
  fi

  # Fallback: отдать WEB_ROOT через busybox httpd (порт 80)
  if [[ -d "${WEB_ROOT}" ]]; then
    log "Веб-сервер не найден. Запускаю fallback httpd на :80, корень=${WEB_ROOT}"
    exec busybox httpd -f -p 0.0.0.0:80 -h "${WEB_ROOT}"
  fi

  log "Не найден веб-корень ${WEB_ROOT}. Оставляю контейнер живым."
  exec tail -f /dev/null
}

case "${1:-run}" in
  run)
    install_if_needed
    start_web
    ;;
  bash|sh)
    exec "$@"
    ;;
  *)
    exec "$@"
    ;;
esac
