#!/bin/sh
set -eu

if [ "$(id -u)" -eq 0 ]; then
  chown -R "${PUID:-1000}:${PGID:-1000}" /pocketbase
  exec su-exec "${PUID:-1000}:${PGID:-1000}" "$0" "$@"
fi

case "${1:-}" in
  migration-worker)
    shift
    exec migration-worker "$@"
    ;;
  pocketbase)
    shift
    ;;
esac

migration-worker sync

exec pocketbase "$@" \
  --dir="${POCKETBASE_DIR:-/pocketbase/data}" \
  --migrationsDir="${POCKETBASE_MIGRATIONS_DIR:-/pocketbase/migrations}/current" \
  --hooksDir="${POCKETBASE_HOOKS_DIR:-/pocketbase/hooks}" \
  --publicDir="${POCKETBASE_PUBLIC_DIR:-/pocketbase/public}" \
  --encryptionEnv=POCKETBASE_ENCRYPTION_KEY
