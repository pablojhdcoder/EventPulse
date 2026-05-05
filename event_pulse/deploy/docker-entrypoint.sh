#!/bin/sh
set -eu
cd /app
exec bin/event_pulse start
