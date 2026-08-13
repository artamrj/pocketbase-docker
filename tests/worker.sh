#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/source/nested" "$tmp/migrations/releases"
printf 'one\n' > "$tmp/source/001_one.js"
printf 'two\n' > "$tmp/source/nested/002_two.js"

first=$("$repo/scripts/migration-hash" "$tmp/source")
second=$("$repo/scripts/migration-hash" "$tmp/source")
[ "$first" = "$second" ]
[ "${#first}" -eq 64 ]

ln -s 001_one.js "$tmp/source/not-allowed"
if "$repo/scripts/migration-hash" "$tmp/source" >/dev/null 2>&1; then
  echo "symlink unexpectedly hashed" >&2
  exit 1
fi
rm "$tmp/source/not-allowed"

mkdir "$tmp/policy"
printf 'migrate(() => {}, () => {})\n' > "$tmp/policy/20260813120000_initial_schema.js"
printf 'migrate(() => {}, () => {})\n' > "$tmp/policy/20260813120100_initial_seed.js"
"$repo/scripts/validate-migrations" "$tmp/policy"
printf 'bad\n' > "$tmp/policy/schema.js"
if "$repo/scripts/validate-migrations" "$tmp/policy" >/dev/null 2>&1; then
  echo "invalid migration filename unexpectedly accepted" >&2
  exit 1
fi

mkdir "$tmp/history"
git -C "$tmp/history" init -q
git -C "$tmp/history" config user.name test
git -C "$tmp/history" config user.email test@example.invalid
mkdir "$tmp/history/pb_migrations"
printf 'initial\n' > "$tmp/history/pb_migrations/20260813120000_initial.js"
git -C "$tmp/history" add pb_migrations
git -C "$tmp/history" commit -qm initial
baseline=$(git -C "$tmp/history" rev-parse HEAD)
printf 'next\n' > "$tmp/history/pb_migrations/20260813130000_next.js"
git -C "$tmp/history" add pb_migrations
git -C "$tmp/history" commit -qm addition
"$repo/scripts/check-migration-history" "$tmp/history" pb_migrations "$baseline"
printf 'edited\n' >> "$tmp/history/pb_migrations/20260813120000_initial.js"
git -C "$tmp/history" add pb_migrations
git -C "$tmp/history" commit -qm forbidden-edit
if "$repo/scripts/check-migration-history" "$tmp/history" pb_migrations "$baseline" >/dev/null 2>&1; then
  echo "migration history edit unexpectedly accepted" >&2
  exit 1
fi

cp -R "$tmp/source" "$tmp/migrations/releases/$first"
ln -s "releases/$first" "$tmp/migrations/current"
PATH="$repo/scripts:$PATH" \
POCKETBASE_MIGRATIONS_DIR="$tmp/migrations" \
MIGRATIONS_SHA256="$first" \
MIGRATIONS_COMMIT=0123456789abcdef0123456789abcdef01234567 \
  "$repo/scripts/migration-worker" verify >/dev/null

printf 'changed\n' >> "$tmp/migrations/releases/$first/001_one.js"
if PATH="$repo/scripts:$PATH" \
  POCKETBASE_MIGRATIONS_DIR="$tmp/migrations" \
  MIGRATIONS_SHA256="$first" \
  MIGRATIONS_COMMIT=0123456789abcdef0123456789abcdef01234567 \
  "$repo/scripts/migration-worker" verify >/dev/null 2>&1; then
  echo "tampered bundle unexpectedly verified" >&2
  exit 1
fi

if PATH="$repo/scripts:$PATH" \
  POCKETBASE_MIGRATIONS_DIR="$tmp/migrations" \
  MIGRATIONS_SHA256="$first" \
  MIGRATIONS_COMMIT=0123456789abcdef0123456789abcdef01234567 \
  MIGRATIONS_URL=https://example.invalid/tarball \
  MIGRATIONS_TOKEN_FILE="$tmp/missing-token" \
  "$repo/scripts/migration-worker" sync >/dev/null 2>&1; then
  echo "sync unexpectedly accepted a missing token" >&2
  exit 1
fi

echo "worker tests passed"
