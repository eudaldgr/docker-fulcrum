# Global arguments
ARG APP_UID=1000
ARG APP_GID=1000

ARG QT_VERSION=6.10
ARG ROCKSDB_VERSION=10.10

FROM ghcr.io/eudaldgr/scratchless AS scratchless
FROM ghcr.io/eudaldgr/scratchless:qt-minimal-${QT_VERSION} AS qt
FROM ghcr.io/eudaldgr/scratchless:rocksdb-${ROCKSDB_VERSION} AS rocksdb

# Build stage
FROM docker.io/alpine AS build
ARG APP_VERSION \
  APP_ROOT \
  TARGETARCH \
  TARGETVARIANT

RUN set -ex; \
  apk --no-cache --update add \
  autoconf \
  brotli-dev \
  bzip2-dev \
  g++ \
  git \
  gnupg \
  jemalloc-dev \
  liburing-dev \
  lz4-dev \
  make \
  openssl-dev \
  pkgconf \
  snappy-dev \
  zeromq-dev \
  zlib-dev \
  zstd-dev;

RUN set -ex; \
  git clone --branch v${APP_VERSION} https://github.com/cculianu/Fulcrum.git;

RUN set -ex; \
  wget -qO- "https://raw.githubusercontent.com/Electron-Cash/keys-n-hashes/master/pubkeys/calinkey.txt" | gpg --import;

RUN set -ex; \
  cd Fulcrum; \
  git verify-commit v${APP_VERSION};

COPY --from=rocksdb / /
COPY --from=qt / /

RUN set -ex; \
  cd Fulcrum; \
  /opt/qt/bin/qmake -makefile \
  PREFIX=/usr \
  Fulcrum.pro \
  "CONFIG-=debug" \
  "CONFIG+=release" \
  "LIBS+=-L/usr/lib -lrocksdb -lz -lbz2 -ljemalloc -lzmq -lzstd -llz4 -luring -lsnappy" \
  "INCLUDEPATH+=/usr/include";

RUN set -ex; \
  cd Fulcrum; \
  make -j "$(nproc)" install;

RUN set -ex; \
  strip /usr/bin/Fulcrum;

COPY --from=scratchless / ${APP_ROOT}/

# Collect all runtime dependencies
RUN set -ex; \
  mkdir -p \
  ${APP_ROOT}/lib \
  ${APP_ROOT}/bin \
  ${APP_ROOT}/data \
  ${APP_ROOT}/etc;
RUN set -ex; \
  cp /usr/bin/Fulcrum ${APP_ROOT}/bin/;
RUN set -ex; \
  cp /usr/bin/FulcrumAdmin ${APP_ROOT}/bin/;

# Copy all required shared libraries
RUN set -ex; \
  ldd ${APP_ROOT}/bin/Fulcrum | awk '{if (match($3,"/")) print $3}' | xargs -I '{}' cp -v '{}' ${APP_ROOT}/lib/ || true;
RUN set -ex; \
  ldd ${APP_ROOT}/bin/FulcrumAdmin | awk '{if (match($3,"/")) print $3}' | xargs -I '{}' cp -v '{}' ${APP_ROOT}/lib/ || true;

# Copy the dynamic linker
RUN set -ex; \
  cp /lib/ld-musl-*.so.1 ${APP_ROOT}/lib/;

# Final scratch image
FROM scratch

ARG TARGETPLATFORM \
  TARGETOS \
  TARGETARCH \
  TARGETVARIANT \
  APP_IMAGE \
  APP_NAME \
  APP_VERSION \
  APP_ROOT \
  APP_UID \
  APP_GID \
  APP_NO_CACHE

ENV APP_IMAGE=${APP_IMAGE} \
  APP_NAME=${APP_NAME} \
  APP_VERSION=${APP_VERSION} \
  APP_ROOT=${APP_ROOT}

COPY --from=build ${APP_ROOT}/ /

ENV DATA_DIR=/data
VOLUME /data

ENV SSL_CERTFILE=${DATA_DIR}/fulcrum.crt
ENV SSL_KEYFILE=${DATA_DIR}/fulcrum.key

EXPOSE 50001 50002

USER ${APP_UID}:${APP_GID}
ENTRYPOINT ["/bin/Fulcrum", "-D", "/data"]