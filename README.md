# PocketBase Docker image

This repository builds one private `linux/amd64` image containing an official
PocketBase binary and the exact migrations it will run:

```text
ghcr.io/artamrj/pocketbase-docker:<pocketbase-version>-m-<migration-hash>
```

Example:

```text
ghcr.io/artamrj/pocketbase-docker:0.39.10-m-a1b2c3d4e5f6
```

There is no migration worker, runtime repository download, migration API, or
mutable `latest` tag. PocketBase applies pending embedded migrations when the
container starts.

## Add migrations

`pb_migrations/` in this repository is the image's migration source. Copy the
existing JavaScript migration files from `artamrj/portfolio` into that directory
before the first build. From then on:

- Never edit, rename, replace, or delete a published migration.
- Add a new migration file for every schema or data change.
- Commit the migration before publishing its image.

Runtime automigration generation is disabled because the embedded directory is
immutable. Create and test schema changes during development, then publish the
new migration in a new image.

Only `.js` files contribute to the canonical migration SHA-256. Paths are
sorted bytewise and each relative path, byte length, and content is hashed.

## Automated build

The [GitHub Actions workflow](.github/workflows/publish.yml) runs every six
hours, manually, or whenever the Dockerfile or `pb_migrations/**` changes. It:

1. Resolves the latest stable official PocketBase release, unless a manual
   version is supplied.
2. Downloads only `linux_amd64` and verifies it against official
   `checksums.txt`.
3. Validates every migration with `node --check`.
4. Applies all migrations twice against an empty temporary database.
5. Builds the final AMD64 image and starts it as UID/GID `1000:1000`.
6. Requires a healthy initial start and restart.
7. Pushes the immutable versioned image to private GHCR.

No cross-repository token or migration policy baseline is required. The only
optional Actions variable is `IMAGE_NAME`, which defaults to
`ghcr.io/artamrj/pocketbase-docker`.

## NAS

Copy `.env.example` to `.env` and select a published tag:

```dotenv
POCKETBASE_VERSION=0.39.10-m-a1b2c3d4e5f6
PUID=1000
PGID=1000
PB_ENCRYPTION_KEY=your-existing-key
```

The included `compose.yaml` retains the data, hooks, and public bind mounts.
There is intentionally no migration bind mount because it would hide the
migrations embedded in the image.

Log in to private GHCR once, then upgrade with:

```sh
docker compose pull pocketbase
docker compose up -d pocketbase
docker compose ps
```

Changing back to an older image does not downgrade the database. Restore a
compatible data backup when a migration is not backward-compatible.

For the one-time development reset, first back up and stop PocketBase. Copy the
existing schema and seed migrations into `pb_migrations/`, reset the development
data directory, publish the new image, and start it against the empty data
directory. CI verifies that the embedded history creates and seeds a fresh
database before publishing.
