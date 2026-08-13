# syntax=docker/dockerfile:1.7
FROM alpine:3.22

ARG POCKETBASE_VERSION
ARG MIGRATIONS_SHA256
ARG BUILD_REVISION

LABEL org.opencontainers.image.title="PocketBase with embedded migrations" \
      org.opencontainers.image.source="https://github.com/artamrj/pocketbase-docker" \
      org.opencontainers.image.version="${POCKETBASE_VERSION}" \
      org.opencontainers.image.revision="${BUILD_REVISION}" \
      io.artamrj.pocketbase.version="${POCKETBASE_VERSION}" \
      io.artamrj.migrations.sha256="${MIGRATIONS_SHA256}"

RUN apk add --no-cache ca-certificates curl

COPY --chmod=0755 .build/pocketbase /usr/local/bin/pocketbase
COPY pb_migrations/ /pocketbase/migrations/

WORKDIR /pocketbase
EXPOSE 8090
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=12 \
  CMD curl --fail http://127.0.0.1:8090/api/health || exit 1
ENTRYPOINT ["/usr/local/bin/pocketbase"]
CMD ["serve", "--http=0.0.0.0:8090", "--dir=/pocketbase/data", "--migrationsDir=/pocketbase/migrations", "--automigrate=false", "--hooksDir=/pocketbase/hooks", "--publicDir=/pocketbase/public", "--encryptionEnv=POCKETBASE_ENCRYPTION_KEY"]
