#!/bin/sh
set -eu

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
