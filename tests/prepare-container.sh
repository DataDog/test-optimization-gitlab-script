#!/bin/sh
# Installs what tests/go-smoke.sh needs in a CI image: Bash, curl and git on
# Alpine, and Python for the intake.
set -eu
if command -v apk >/dev/null 2>&1; then
  apk add --no-cache bash curl git python3
elif ! command -v python3 >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq python3 >/dev/null
fi
