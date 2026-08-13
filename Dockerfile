# syntax=docker/dockerfile:1.7
FROM alpine:3.22

ARG POCKETBASE_VERSION
ARG MIGRATIONS_COMMIT
ARG MIGRATIONS_SHA256
ARG MIGRATIONS_SUBDIR=pb_migrations
ARG BUILD_REVISION

LABEL org.opencontainers.image.title="PocketBase with pinned migrations" \
      org.opencontainers.image.source="https://github.com/artamrj/pocketbase-docker" \
      org.opencontainers.image.version="${POCKETBASE_VERSION}" \
      org.opencontainers.image.revision="${BUILD_REVISION}" \
      io.artamrj.pocketbase.version="${POCKETBASE_VERSION}" \
      io.artamrj.migrations.commit="${MIGRATIONS_COMMIT}" \
      io.artamrj.migrations.sha256="${MIGRATIONS_SHA256}" \
      io.artamrj.migrations.subdir="${MIGRATIONS_SUBDIR}"

RUN apk add --no-cache ca-certificates coreutils curl findutils tar

COPY --chmod=0755 .build/pocketbase /usr/local/bin/pocketbase
COPY --chmod=0755 scripts/migration-hash /usr/local/bin/migration-hash
COPY --chmod=0755 scripts/migration-worker /usr/local/bin/migration-worker
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

ENV POCKETBASE_DIR=/pocketbase/data \
    POCKETBASE_MIGRATIONS_DIR=/pocketbase/migrations \
    POCKETBASE_HOOKS_DIR=/pocketbase/hooks \
    POCKETBASE_PUBLIC_DIR=/pocketbase/public \
    MIGRATIONS_COMMIT=${MIGRATIONS_COMMIT} \
    MIGRATIONS_SHA256=${MIGRATIONS_SHA256} \
    MIGRATIONS_SUBDIR=${MIGRATIONS_SUBDIR} \
    MIGRATIONS_TOKEN_FILE=/run/secrets/github_token

WORKDIR /pocketbase
EXPOSE 8090
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=12 \
  CMD curl --fail http://127.0.0.1:8090/api/health || exit 1
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["serve", "--http=0.0.0.0:8090"]
