#!/usr/bin/env bash
# hard-stop-runner.sh
#
# Replaces the every-minute /api/cron/hard-stop Vercel cron.
# Vercel Hobby/Pro bill 1440 invocations/day per every-minute cron —
# that's the biggest slice of the cron overage.
#
# This runner is invoked by hard-stop.timer on Hetzner (OnUnitActiveSec=60s)
# and makes an internal authenticated call to the Hub endpoint, which is
# still served by Vercel but no longer triggered FROM Vercel.
#
# Env: SMARTER_HUB_URL (e.g. https://smarter.poker), CRON_SECRET
set -euo pipefail

: "${SMARTER_HUB_URL:?SMARTER_HUB_URL must be set}"
: "${CRON_SECRET:?CRON_SECRET must be set}"

URL="${SMARTER_HUB_URL%/}/api/cron/hard-stop"

# --max-time 25 keeps us well under the 60s timer interval so overlap never happens.
resp=$(curl -sS --max-time 25 \
  -H "Authorization: Bearer ${CRON_SECRET}" \
  -H "X-Cron-Source: hetzner-systemd" \
  -w '\n__HTTP__%{http_code}__%{time_total}\n' \
  "${URL}" || echo '__HTTP__000__0')

status=$(printf '%s' "${resp}" | tail -n1 | awk -F__ '{print $3}')
dur=$(printf '%s' "${resp}" | tail -n1 | awk -F__ '{print $4}')
body=$(printf '%s' "${resp}" | sed '$d')

printf 'hard-stop status=%s duration=%s body=%s\n' \
  "${status:-unknown}" "${dur:-unknown}" "$(printf '%s' "${body}" | tr '\n' ' ' | head -c 500)"

if [[ "${status}" != "200" ]]; then exit 1; fi
