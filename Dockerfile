# syntax=docker/dockerfile:1.7
FROM alpine:3.22

ARG POCKETBASE_VERSION

LABEL org.opencontainers.image.title="PocketBase" \
      org.opencontainers.image.source="https://github.com/artamrj/pocketbase-docker" \
      org.opencontainers.image.version="${POCKETBASE_VERSION}"

RUN apk add --no-cache ca-certificates curl tar su-exec

COPY --chmod=0755 .build/pocketbase /usr/local/bin/pocketbase
COPY --chmod=0755 scripts/migration-worker /usr/local/bin/migration-worker
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

ENV POCKETBASE_DIR=/pocketbase/data \
    POCKETBASE_MIGRATIONS_DIR=/pocketbase/migrations \
    POCKETBASE_HOOKS_DIR=/pocketbase/hooks \
    POCKETBASE_PUBLIC_DIR=/pocketbase/public \
    MIGRATIONS_TOKEN_FILE=/run/secrets/github_token \
    PUID=1000 \
    PGID=1000

WORKDIR /pocketbase
EXPOSE 8090
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=12 \
  CMD curl --fail http://127.0.0.1:8090/api/health || exit 1
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["serve", "--http=0.0.0.0:8090"]
