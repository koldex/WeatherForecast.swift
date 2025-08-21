#!/usr/bin/env bash
# Quick health check for OpenWeatherMap endpoints without leaking secrets
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
cd "$REPO_DIR"

if [[ -z "${OPENWEATHERMAP_API_KEY:-}" ]]; then
  if command -v direnv >/dev/null 2>&1; then
    # Try to load via direnv (non-interactive)
    direnv export bash >/dev/null 2>&1 || true
  fi
fi

if [[ -z "${OPENWEATHERMAP_API_KEY:-}" ]]; then
  echo "ERROR: OPENWEATHERMAP_API_KEY is not set. Use direnv (.env.local) or export it in your shell." >&2
  exit 1
fi

CITY=$(jq -r .city config.json 2>/dev/null || echo "Lappeenranta")
COUNTRY=$(jq -r .country config.json 2>/dev/null || echo "FI")

BASE="https://api.openweathermap.org/data/2.5"

for END in weather forecast; do
  URL="$BASE/$END?q=${CITY},${COUNTRY}&units=metric&appid=${OPENWEATHERMAP_API_KEY}"
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
  echo "$END -> HTTP $CODE"
  sleep 1
done
