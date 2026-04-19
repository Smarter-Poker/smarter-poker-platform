#!/usr/bin/env bash
# Copies every .service / .timer under systemd/ to /etc/systemd/system/,
# reloads the daemon, and enables the default timers. Idempotent.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SYSTEMD_DIR="${REPO_DIR}/systemd"
TARGET_DIR="/etc/systemd/system"

ENABLED_TIMERS=(
  "hard-stop.timer"
  "scheduled-table-opener.timer"
)

if [[ "${EUID}" -ne 0 ]]; then
  echo "install-systemd-units.sh must run as root (use sudo)" >&2
  exit 1
fi

echo "==> installing units from ${SYSTEMD_DIR}"
for f in "${SYSTEMD_DIR}"/*.service "${SYSTEMD_DIR}"/*.timer; do
  [[ -f "${f}" ]] || continue
  name="$(basename "${f}")"
  install -m 0644 "${f}" "${TARGET_DIR}/${name}"
  echo "  installed ${name}"
done

echo "==> daemon-reload"
systemctl daemon-reload

for t in "${ENABLED_TIMERS[@]}"; do
  echo "==> enable --now ${t}"
  systemctl enable --now "${t}"
done

echo "==> done. Status:"
systemctl list-timers --no-pager | grep -E 'hard-stop|scheduled-table-opener' || true
