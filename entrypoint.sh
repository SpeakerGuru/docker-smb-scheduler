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

  # fallback: если ADD не скачал, попробуем ещё раз
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

  # Гарантируем, что путь по умолчанию для httpd существует (Apache установлен в образе)
  mkdir -p /etc/apache2/sites-enabled

  log "Запускаю установку в non-interactive (подаю пустые ответы)…"
  cd "${INSTALL_DIR}"
  chmod +x ./smb_scheduler_install.sh || true
  yes '' | bash ./smb_scheduler_install.sh

  log "Установка завершена. Ставлю флаг."
  touch "${FLAG_FILE}"

  # Симлинк UI, если положили в /var/www/smb_scheduler
  if [[ -d "/var/www/smb_scheduler" && ! -e "${WEB_ROOT}/smb_scheduler" ]]; then
    ln -s "/var/www/smb_scheduler" "${WEB_ROOT}/smb_scheduler" || true
  fi
}

start_web() {
  if command -v apache2ctl >/dev/null 2>&1; then
    log "Запускаю Apache в foreground."
    exec apache2ctl -D FOREGROUND
  fi
  # запасной вариант
  if command -v busybox >/dev/null 2>&1; then
    log "Apache не найден. Fallback httpd на :80, корень=${WEB_ROOT}"
    exec busybox httpd -f -p 0.0.0.0:80 -h "${WEB_ROOT}"
  fi
  log "Нет веб-сервера. Оставляю контейнер живым."
  exec tail -f /dev/null
}

case "${1:-run}" in
  run) install_if_needed; start_web ;;
  bash|sh) exec "$@" ;;
  *) exec "$@" ;;
esac
