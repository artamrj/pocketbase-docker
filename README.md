# Private PocketBase image

This repository builds one immutable `linux/amd64` PocketBase image from an
official PocketBase release and a pinned migration revision:

```text
ghcr.io/artamrj/pocketbase-docker:<pocketbase-version>-m-<migration-hash-prefix>
```

For example: `ghcr.io/artamrj/pocketbase-docker:0.39.10-m-a1b2c3d4e5f6`.
There is deliberately no `latest` tag.

## GitHub configuration

The workflow runs every six hours, on demand, and when image/worker files or
`pb_migrations/**` in this repository change. It polls the migration repository
on scheduled runs, so migration commits in that repository are picked up within
six hours. A repository dispatch with event type `migrations-changed` can be
sent by the migration repository for immediate builds.

Configure these Actions values:

- Secret `MIGRATIONS_REPO_TOKEN`: fine-grained token with read-only Contents
  access to `artamrj/portfolio`. It is used only to check out/test migrations
  and to test the final container.
- Variable `MIGRATIONS_REPOSITORY` (optional): defaults to
  `artamrj/portfolio`.
- Variable `MIGRATIONS_SUBDIR` (optional): defaults to `pb_migrations`.
- Variable `MIGRATIONS_URL` (optional): defaults to
  `https://api.github.com/repos/artamrj/portfolio/tarball`.
- Variable `MIGRATIONS_POLICY_BASE` (required): the full commit created by the
  one-time timestamp rename/reset. CI treats changes after this commit as the
  immutable migration era.
- Variable `IMAGE_NAME` (optional): defaults to
  `ghcr.io/artamrj/pocketbase-docker`.

The workflow resolves the latest non-draft, non-prerelease PocketBase release.
Manual runs may set an exact version (with or without a leading `v`) and an
exact migration ref. Official `checksums.txt` is checked before the binary is
used. The complete migration hash and exact migration commit are embedded in
the image labels and runtime environment.

## Migration hash

[`scripts/migration-hash`](scripts/migration-hash) defines the canonical hash.
For every regular file below the migration directory, sorted bytewise by its
relative path, it hashes this unambiguous stream:

```text
relative-path NUL file-byte-length NUL file-contents NUL
```

Paths containing newlines are supported. A NUL in a Unix path is impossible.
Directories may contain only regular files and directories; symbolic links and
other special entries are rejected.
The first 12 lowercase hexadecimal characters are used in the image tag; the
full SHA-256 remains embedded in the image.

## Runtime behavior

The entrypoint runs `migration-worker sync` before PocketBase. Sync always
authenticates and downloads `MIGRATIONS_URL/<embedded-commit>`, selects only
the configured migration subtree from the safely extracted archive, verifies
the complete embedded SHA-256, and installs it as:

```text
/pocketbase/migrations/releases/<full-hash>/
```

It then atomically changes `/pocketbase/migrations/current`. Any authentication,
download, archive, extraction, or hash failure prevents PocketBase from
starting. It never follows a moving branch and exposes no service or port.

Available container commands:

```sh
migration-worker status
migration-worker sync
migration-worker verify
migration-worker gc
```

`gc` removes inactive cached releases whose directory names are full SHA-256
values. It preserves the active release and ignores every other directory. It
never touches PocketBase data or migration history.

## Migration policy

Migration filenames are immutable UTC timestamps, for example:

```text
20260813120000_initial_schema.js
20260813120100_initial_seed.js
```

During the one permitted development reset, back up the NAS data, rename the
existing initial schema and seed migrations to ordered UTC timestamp names,
commit them, and reset the development database. Once deployed, never edit,
replace, rename, or delete a migration. Add a new timestamped migration for
every schema or data transition. CI accepts any number of migrations, but
enforces top-level `YYYYMMDDHHMMSS_description.js` names with unique timestamps.
Starting after `MIGRATIONS_POLICY_BASE`, it walks every commit and rejects a
modification, deletion, rename, or type change under `pb_migrations`; additions
remain allowed.

## NAS deployment

`.env`:

```dotenv
POCKETBASE_VERSION=0.39.10-m-a1b2c3d4e5f6
PUID=1000
PGID=1000
PB_ENCRYPTION_KEY=your-existing-key
MIGRATIONS_URL=https://api.github.com/repos/artamrj/portfolio/tarball
```

The checked-in [`compose.yaml`](compose.yaml) uses:

```yaml
services:
  pocketbase:
    image: ghcr.io/artamrj/pocketbase-docker:${POCKETBASE_VERSION}
    user: ${PUID}:${PGID}
    restart: unless-stopped
    init: true
    ports:
      - "8090:8090"
    environment:
      POCKETBASE_DEBUG: "false"
      POCKETBASE_ENCRYPTION_KEY: ${PB_ENCRYPTION_KEY}
      MIGRATIONS_URL: ${MIGRATIONS_URL}
      MIGRATIONS_TOKEN_FILE: /run/secrets/github_token
    volumes:
      - ./data:/pocketbase/data
      - ./migrations:/pocketbase/migrations
      - ./hooks:/pocketbase/hooks
      - ./public:/pocketbase/public
    secrets:
      - github_token
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://127.0.0.1:8090/api/health"]
      interval: 10s
      timeout: 3s
      retries: 12
      start_period: 10s
    stop_grace_period: 20s

secrets:
  github_token:
    file: ./secrets/github_token
```

Create `./secrets/github_token`, owned by `PUID`, with mode `0600`. Use a
fine-grained GitHub token with read-only Contents access to the private migration
repository and read-only Packages access, and use it once with
`docker login ghcr.io`.

Upgrade only by changing `POCKETBASE_VERSION`, then:

```sh
docker compose pull pocketbase
docker compose up -d pocketbase
docker compose ps
```

Rollback selects the prior image tag. Database downgrade is intentionally not
automatic; restore a compatible backup when a migration is not backward-safe.

Before the first development reset, stop PocketBase and make a restorable copy
of `./data`. After committing the renamed timestamped migrations, move the old
development data aside (do not delete the backup), create an empty writable
`./data`, select the newly published image tag, and start the service. The
workflow has already proven that the same migration set creates and seeds an
empty database.
