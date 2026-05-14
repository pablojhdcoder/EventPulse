#!/bin/sh
set -eu
cd /app
# Siempre el hostname del contenedor (Compose `hostname:`), no el ENV de build.
export HOSTNAME="$(hostname 2>/dev/null || echo localhost)"
exec bin/event_pulse start
