#!/usr/bin/env bash
# scheduled-table-opener-runner.sh
#
# Replaces the */5-minute /api/cron/scheduled-table-opener Vercel cron.
# Invoked by scheduled-table-opener.timer on Hetzner (OnCalendar=*:0/5).
#
# Env: SMARTER_HUB_URL, CRON_SECRET
set -euo pipefail

: "${SMARTER_HUB_URL:?SMARTER_HUB_URL must be set}"
: "${CRON_SECRET:?CRON_SECRET must be set}"

URL="${SMARTER_HUB_URL%/}/api/cron/scheduled-table-opener"

resp=$(curl -sS --max-time 120 \
  -H "Authorization: Bearer ${CRON_SECRET}" \
  -H "X-Cron-Source: hetzner-systemd" \
  -w '\n__HTTP__%{http_code}__%{time_total}\n' \
  "${URL}" || echo '__HTTP__000__0')

status=$(printf '%s' "${resp}" | tail -n1 | awk -F__ '{print $3}')
dur=$(printf '%s' "${resp}" | tail -n1 | awk -F__ '{print $4}')
body=$(printf '%s' "${resp}" | sed '$d')

printf 'scheduled-table-opener status=%s duration=%s body=%s\n' \
  "${status:-unknown}" "${dur:-unknown}" "$(printf '%s' "${body}" | tr '\n' ' ' | head -c 500)"

if [[ "${status}" != "200" ]]; then exit 1; fi
