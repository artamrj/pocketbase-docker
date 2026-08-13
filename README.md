# PocketBase on your NAS

A minimal PocketBase Docker image for your NAS. The official PocketBase binary
is pinned by version; migrations are pulled from a private GitHub repo at
runtime. No hashing, no cron, no immutable-migration machinery.

## How it works

- **Image**: `ghcr.io/artamrj/pocketbase-docker:<version>` — built from the
  official PocketBase release, verified against its `checksums.txt`. Pick any
  PocketBase version, for example `0.39.10`.
- **Migrations**: on every container start, a small worker downloads the latest
  migration files from `artamrj/pocketbase-migrations` (main branch), validates
  filenames, and swaps them in atomically. PocketBase then applies new migrations
  against its `_migrations` table.
- **Trigger**: updates happen with an internal command only — never exposed.

## Build the image

GitHub Actions builds and pushes `:<version>` on every push and on demand.
Manual build for a specific version:

```sh
docker build -t ghcr.io/artamrj/pocketbase-docker:0.39.10 \
  --build-arg POCKETBASE_VERSION=0.39.10 .
```

## Deploy on the NAS

`.env`:

```dotenv
POCKETBASE_VERSION=0.39.10
PUID=1000
PGID=1000
PB_ENCRYPTION_KEY=your-existing-key
MIGRATIONS_REPOSITORY=artamrj/pocketbase-migrations
MIGRATIONS_BRANCH=main
MIGRATIONS_TOKEN=github_token_here
```

The token needs fine-grained **read-only Contents** access to
`artamrj/pocketbase-migrations`. Use the token once with `docker login ghcr.io`.

```sh
docker compose up -d
```

On every start the entrypoint (running as root) chowns `/pocketbase` to
`PUID:PGID` and then drops privileges with `su-exec`, so the mounted `./data`
and `./migrations` directories never need manual permission fixes.

## Upgrade PocketBase

```sh
docker compose pull pocketbase
docker compose up -d pocketbase
```

## Deploy new migrations

```sh
docker compose exec pocketbase migration-worker sync
docker compose restart pocketbase
```

`sync` downloads the latest migrations; the restart re-syncs on boot and makes
PocketBase apply them. To inspect the installed files:

```sh
docker compose exec pocketbase migration-worker status
```

## Rules for migrations

Migrations are plain PocketBase JS migrations named
`YYYYMMDDHHMMSS_description.js`, for example:

```text
20260813120000_initial_schema.js
20260813120100_initial_seed.js
```

The `artamrj/pocketbase-migrations` repo holds the `.js` files directly at the
repository root (a `pb_migrations/` subdirectory is also accepted). Other files
such as a `README.md` are ignored. The worker rejects any other `.js` filename.
Only **add** new timestamped files. PocketBase verifies the checksum of every
applied migration at startup, so editing, renaming, or deleting an
already-applied migration will stop the container. To change an applied
migration, add a new one.
