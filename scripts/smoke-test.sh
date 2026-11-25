#!/usr/bin/env bash
set -euo pipefail

usage() { echo "Usage: CLINIC_ID=1 BOOKING_DATE=YYYY-MM-DD $0 <url> [--basic|--staff]" >&2; exit 2; }
fail() { echo "$1" >&2; exit 1; }

[[ $# -ge 1 && $# -le 2 ]] || usage
base=${1%/}
mode=${2:---staff}
[[ $mode == --basic || $mode == --staff ]] || usage
[[ $base == http://* || $base == https://* ]] || usage
clinic=${CLINIC_ID:-1}
day=${BOOKING_DATE:-$(jq -nr 'now + (60 * 86400) | strftime("%Y-%m-%d")')}
[[ $clinic =~ ^[1-9][0-9]*$ && $day =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || usage

response=$(mktemp)
trap 'rm -f "$response"' EXIT
request() {
  local path=$1 expected=$2 status
  shift 2
  status=$(curl -q --silent --globoff --connect-timeout 5 --max-time 15 \
    --output "$response" --write-out '%{http_code}' "$@" -- "$base$path") ||
    fail "Request to ${path%%\?*} failed"
  [[ $status == "$expected" ]] || fail "${path%%\?*} returned HTTP $status (expected $expected)"
}

request /healthz 200
query="clinic_id=$clinic&date=$day"
request "/api/slots?$query" 200
hour=$(jq -er --argjson pick "$RANDOM" '
  map(select(.available == true) | .hour | numbers) | select(length > 0) | .[$pick % length]
' "$response" 2>/dev/null) || fail "No available slot or invalid slots response"

payload=$(jq -nc --argjson clinic "$clinic" --arg day "$day" --argjson hour "$hour" \
  '{clinic_id:$clinic, slot_date:$day, slot_hour:$hour, patient_name:"ClinicFlow Smoke", mobile:"0000000000"}')
request /api/bookings 201 --header 'Content-Type: application/json' --data "$payload"
id=$(jq -er '.id | numbers | select(. > 0 and . == floor)' "$response" 2>/dev/null) ||
  fail "Booking response did not contain a valid ID"

if [[ $mode == --basic ]]; then
  echo "Public basic checks passed. Booking lookup was skipped; CF-505 is incomplete."
  exit 0
fi

request "/api/bookings?$query" 200
jq -e --argjson id "$id" --argjson clinic "$clinic" --arg day "$day" --argjson hour "$hour" '
  type == "array" and any(.[]; .id == $id and .clinic_id == $clinic and .slot_date == $day and .slot_hour == $hour)
' "$response" >/dev/null 2>&1 || fail "Created booking absent from the controlled schedule"
echo "Controlled smoke passed. The schedule contains the newly created booking."
