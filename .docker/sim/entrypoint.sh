#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/root/smb_scheduler_install"
ARCHIVE="/tmp/smb_scheduler_install-latest.tar.gz"
DATA_DIR="/data"
FLAG_FILE="${DATA_DIR}/.installed"

DB_HOST="${DB_HOST:-db}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-}"

log(){ echo "[sim] $*"; }

mysql_wait() {
  for i in {1..60}; do
    if mysqladmin --host="${DB_HOST}" --user="${DB_USER}" --password="${DB_PASS}" ping --silent; then
      return 0
    fi
    sleep 1
  done
  log "DB not ready"; exit 1
}

install_if_needed() {
  [[ -f "${FLAG_FILE}" ]] && { log "Already installed."; return; }

  [[ -s "${ARCHIVE}" ]] || wget -O "${ARCHIVE}" "http://dbltek.com/update/smb_scheduler_install-latest.tar.gz"

  mkdir -p /root /var/www/html /etc/apache2/sites-enabled
  tar -xvzf "${ARCHIVE}" -C /root
  [[ -d "${INSTALL_DIR}" ]] || { log "No ${INSTALL_DIR} after extract"; exit 1; }

  # Обход: скрипт зовёт /usr/bin/mysql без -h. Подменим «вперёд» в PATH.
  cat >/usr/local/bin/mysql <<EOF
#!/usr/bin/env bash
exec /usr/bin/mysql -h "${DB_HOST}" -u "${DB_USER}" ${DB_PASS:+-p${DB_PASS}} "\$@"
EOF
  chmod +x /usr/local/bin/mysql

  log "Waiting DB…"; mysql_wait

  log "Run installer (auto-enter)…"
  cd "${INSTALL_DIR}"
  chmod +x ./smb_scheduler_install.sh || true
  yes '' | bash ./smb_scheduler_install.sh

  touch "${FLAG_FILE}"

  # Если UI положили в /var/www/smb_scheduler — сделаем симлинк в общий www
  if [[ -d "/var/www/smb_scheduler" && ! -e "/var/www/html/smb_scheduler" ]]; then
    ln -s "/var/www/smb_scheduler" "/var/www/html/smb_scheduler" || true
  fi
}

start_sim() {
  for bin in smb_scheduler smb_watchd xchanged; do
    if [[ -x "/usr/local/smb_scheduler/${bin}" ]]; then
      log "Starting ${bin}…"
      "/usr/local/smb_scheduler/${bin}" || true
    fi
  done
}

case "${1:-run}" in
  run) install_if_needed; start_sim; tail -f /dev/null ;;
  *) exec "$@" ;;
esac
