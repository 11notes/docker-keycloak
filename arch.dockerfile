# ╔═════════════════════════════════════════════════════╗
# ║                       SETUP                         ║
# ╚═════════════════════════════════════════════════════╝
# GLOBAL
  ARG APP_UID=1000 \
      APP_GID=1000 \
      APP_GO_VERSION=0

# :: FOREIGN IMAGES
  FROM 11notes/distroless:localhealth AS distroless-localhealth
  FROM 11notes/distroless AS distroless
  FROM 11notes/util AS util

# ╔═════════════════════════════════════════════════════╗
# ║                       BUILD                         ║
# ╚═════════════════════════════════════════════════════╝
# :: ENTRYPOINT
  FROM 11notes/go:${APP_GO_VERSION} AS entrypoint
  ARG APP_GO_VERSION
  COPY ./build/go/entrypoint /go/entrypoint
  RUN set -ex; \
    cd /go/entrypoint; \
    go mod edit -go=${APP_GO_VERSION}; \
    eleven go build /entrypoint main.go; \
    eleven distroless /entrypoint;

# :: KEYCLOAK
  FROM eclipse-temurin:21-jdk-jammy AS build
  COPY --from=util / /
  ARG APP_VERSION \
      BUILD_SRC=https://github.com/keycloak/keycloak.git \
      BUILD_ROOT=keycloak
  ENV KC_DB="postgres" \
      KC_DB_URL_HOST="postgres" \
      KC_DB_URL_DATABASE="postgres" \
      KC_DB_USERNAME="postgres" \
      KC_BOOTSTRAP_ADMIN_USERNAME="tmpadmin" \
      KC_HEALTH_ENABLED=true \
      KC_METRICS_ENABLED=true \
      KC_HTTP_ENABLED=true \
      KC_HOSTNAME_STRICT=false \
      KC_PROXY_HEADERS=xforwarded

  RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
      git \
      libicu-dev \
      unzip;

  RUN set -eux; \
    eleven git clone ${BUILD_SRC} ${APP_VERSION};

  RUN set -eux; \
    cd ${BUILD_ROOT}; \
    ./mvnw clean install -DskipTests -pl quarkus/dist -am;

  RUN set -eux; \
    cd ${BUILD_ROOT}; \
    cd quarkus/dist/target; \
    unzip keycloak-${APP_VERSION}.zip -d /tmp/kc-extract; \
    mv /tmp/kc-extract/keycloak-${APP_VERSION} /opt/keycloak;

  RUN set -eux; \
    cd /opt/keycloak; \
    ./bin/kc.sh build;

# :: DISTROLESS JRE
  FROM eclipse-temurin:21-jdk-jammy AS build-jre
  COPY --from=util / /
  COPY --from=build /opt/keycloak /opt/keycloak

  RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
      binutils;

  RUN set -eux; \
    jlink \
      --add-modules java.base,java.desktop,java.instrument,java.management,java.naming,java.net.http,java.security.jgss,java.security.sasl,java.sql,java.transaction.xa,java.xml,java.logging,java.rmi,jdk.crypto.ec,jdk.crypto.cryptoki,jdk.unsupported,jdk.zipfs,java.scripting,java.compiler \
      --strip-debug --no-man-pages --no-header-files \
      --output /opt/jre-minimal;

  RUN set -eux; \
    mkdir -p /opt/libs; \
    { ldd /opt/jre-minimal/bin/java; ldd /opt/jre-minimal/lib/server/libjvm.so; } \
      | awk '{print $(NF-1)}' | grep '^/' | sort -u \
      | while read -r lib; do \
          mkdir -p "/opt/libs$(dirname "$lib")"; \
          cp -L "$lib" "/opt/libs$lib"; \
        done; \
    INTERP=$(readelf -l /opt/jre-minimal/bin/java | grep 'Requesting program interpreter' | sed -E 's/.*: (.*)\]/\1/'); \
    mkdir -p "/opt/libs$(dirname "$INTERP")"; \
    cp -L "$INTERP" "/opt/libs$INTERP"

# :: FILE SYSTEM
  FROM alpine AS file-system
  COPY --from=util / /
  ARG APP_ROOT
  USER root

  RUN set -eux; \
    eleven mkdir /distroless${APP_ROOT}/{etc};


# ╔═════════════════════════════════════════════════════╗
# ║                       IMAGE                         ║
# ╚═════════════════════════════════════════════════════╝
  # :: HEADER
  FROM scratch

  # :: default arguments
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

  # :: default environment
    ENV APP_IMAGE=${APP_IMAGE} \
        APP_NAME=${APP_NAME} \
        APP_VERSION=${APP_VERSION} \
        APP_ROOT=${APP_ROOT}

  # :: app specific environment
    ENV KC_DB="postgres" \
        KC_DB_URL_HOST="postgres" \
        KC_DB_URL_DATABASE="postgres" \
        KC_DB_USERNAME="postgres" \
        KC_BOOTSTRAP_ADMIN_USERNAME="tmpadmin" \
        KC_HEALTH_ENABLED=true \
        KC_METRICS_ENABLED=true \
        KC_HTTP_ENABLED=true \
        KC_HOSTNAME_STRICT=false \
        KC_PROXY_HEADERS=xforwarded

  # :: multi-stage
    COPY --from=distroless / /
    COPY --from=distroless-localhealth / /
    COPY --from=build-jre /opt/libs/ /
    COPY --from=build-jre /opt/jre-minimal /opt/jre-minimal
    COPY --from=build --chown=${APP_UID}:${APP_GID} /opt/keycloak /opt/keycloak
    COPY --from=entrypoint /distroless/ /
    COPY --from=file-system --chown=${APP_UID}:${APP_GID} /distroless/ /

# :: PERSISTENT DATA
  VOLUME ["${APP_ROOT}/etc"]

# :: MONITORING
  HEALTHCHECK --interval=5s --timeout=2s --start-period=5s \
    CMD ["/usr/local/bin/localhealth", "http://127.0.0.1:9000/metrics"]

# :: EXECUTE
  USER ${APP_UID}:${APP_GID}
  ENTRYPOINT ["/usr/local/bin/entrypoint"]