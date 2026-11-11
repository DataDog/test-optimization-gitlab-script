#!/bin/sh
# Installs what tests/go-smoke.sh needs in a CI image: Bash, curl and git on
# Alpine, and Python for the intake. With WITHOUT_CURL=1, Alpine gets no curl,
# so script.sh and the installer download with BusyBox's wget.
set -eu
if command -v apk >/dev/null 2>&1; then
  if [ "${WITHOUT_CURL:-}" = "1" ]; then
    apk add --no-cache bash git python3
  else
    apk add --no-cache bash curl git python3
  fi
elif ! command -v python3 >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq python3 >/dev/null
fi
