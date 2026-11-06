#!/bin/sh
set -eu
umask 077
if [ "$(id -u)" = 0 ]; then
    install -d -m 700 -o 10001 -g 10001 \
        /var/lib/teacher-workbench /var/lib/teacher-workbench-keyring
    exec gosu workbench "$0" "$@"
fi
if [ "${1:-serve}" = serve ]; then
    exec python -m docker.launcher
fi
exec "$@"
