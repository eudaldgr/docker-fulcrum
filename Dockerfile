# Build RocksDB from source
FROM docker.io/alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 AS qt
WORKDIR /build

RUN set -ex; \
  apk --no-cache --update add \
  git \
  g++ \
  samurai \
  cmake \
  mesa-dev \
  curl-dev;

RUN set -ex; \
  git clone --branch v6.10.2 https://github.com/qt/qtbase.git /build;

RUN set -ex; \
  ./configure \
  -static \
  -release \
  -prefix "/opt/qt" \
  -c++std c++20 \
  -nomake tests \
  -nomake examples \
  -no-feature-testlib \
  -no-gui \
  -no-dbus \
  -no-widgets \
  -no-feature-animation \
  -openssl \
  -openssl-linked \
  -optimize-size \
  -feature-optimize_full;

RUN set -ex; \
  cmake --build . --parallel; \
  cmake --install .;

# Build RocksDB from source
FROM docker.io/alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 AS rocksdb
WORKDIR /build

RUN set -ex; \
  apk --no-cache --update add \
  bash \
  clang \
  git \
  linux-headers \
  make \
  perl \
  snappy-dev;

RUN set -ex; \
  git clone --branch v10.9.1 https://github.com/facebook/rocksdb.git /build;

RUN set -ex; \
  sed 's/install -C/install -c/g' Makefile > _;

RUN set -ex; \
  mv -f _ Makefile;

RUN set -ex; \
  PORTABLE=1 \
  DISABLE_JEMALLOC=1 \
  DEBUG_LEVEL=0 \
  USE_RTTI=1 \
  make static_lib;

RUN set -ex; \
  PREFIX=/build/rocksdb-install \
  make install-static;

# Build stage
FROM docker.io/alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 AS builder

ARG VERSION
ARG TARGETPLATFORM
ARG KEYS

ARG APP_UID=1000
ARG APP_GID=1000

WORKDIR /build

# Set optimized compiler flags
ENV CFLAGS="-O3 -pipe -fPIE"
ENV CXXFLAGS="-O3 -pipe -fPIE"
ENV LDFLAGS="-pie -Wl,--as-needed"
ENV MAKEFLAGS="-j$(nproc)"

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
  git clone --branch v${VERSION} https://github.com/cculianu/Fulcrum.git /build;

RUN set -ex; \
  wget -qO- "https://raw.githubusercontent.com/Electron-Cash/keys-n-hashes/master/pubkeys/calinkey.txt" | gpg --import;

RUN set -ex; \
  git verify-commit v${VERSION};

COPY --from=rocksdb /build/rocksdb-install /usr/
COPY --from=qt /opt /opt/

RUN set -ex; \
  /opt/qt/bin/qmake -makefile \
  PREFIX=/usr \
  Fulcrum.pro \
  "CONFIG-=debug" \
  "CONFIG+=release" \
  "LIBS+=-L/usr/lib -lrocksdb -lz -lbz2 -ljemalloc -lzmq -lzstd -llz4 -luring -lsnappy" \
  "INCLUDEPATH+=/usr/include";

RUN set -ex; \
  make -j "$(nproc)" install;

RUN set -ex; \
  strip /usr/bin/Fulcrum;

# Collect all runtime dependencies
RUN set -ex; \
  mkdir -p \
  /runtime/lib \
  /runtime/bin \
  /runtime/data \
  /runtime/etc;
RUN set -ex; \
  cp /usr/bin/Fulcrum /runtime/bin/;
RUN set -ex; \
  cp /usr/bin/FulcrumAdmin /runtime/bin/;

# Copy all required shared libraries
RUN set -ex; \
  ldd /runtime/bin/Fulcrum | awk '{if (match($3,"/")) print $3}' | xargs -I '{}' cp -v '{}' /runtime/lib/ || true;
RUN set -ex; \
  ldd /runtime/bin/FulcrumAdmin | awk '{if (match($3,"/")) print $3}' | xargs -I '{}' cp -v '{}' /runtime/lib/ || true;

# Copy the dynamic linker
RUN set -ex; \
  cp /lib/ld-musl-*.so.1 /runtime/lib/;

RUN set -ex; \
  echo "fulcrum:x:${APP_UID}:${APP_GID}:fulcrum:/data:/sbin/nologin" > /runtime/etc/passwd;
RUN set -ex; \
  echo "fulcrum:x:${APP_GID}:" > /runtime/etc/group;

RUN set -ex; \
  chown -R ${APP_UID}:${APP_GID} /runtime/data;

# Final scratch image
FROM scratch
LABEL org.opencontainers.image.authors="Eudald Gubert i Roldan <https://eudald.gr>"

ARG APP_UID=1000
ARG APP_GID=1000

# Copy everything from runtime
COPY --from=builder /runtime/ /

ENV DATA_DIR=/data
VOLUME /data

ENV SSL_CERTFILE=${DATA_DIR}/fulcrum.crt
ENV SSL_KEYFILE=${DATA_DIR}/fulcrum.key

EXPOSE 50001 50002

USER ${APP_UID}:${APP_GID}
ENTRYPOINT ["/bin/Fulcrum", "-D", "/data"]
