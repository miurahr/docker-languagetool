ARG LT_VERSION=6.5
ARG LT_REVISION=omt1.0
FROM openjdk:21-jdk-slim as base

FROM base as prepare

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN set -eux; \
    apt update && apt install -y -qq wget unzip

ARG LT_VERSION
ARG LT_REVISION

RUN set -eux; \
    wget -O /tmp/LanguageTool-${LT_VERSION}.zip https://github.com/miurahr/languagetool/archive/refs/heads/omegat-${LT_VERSION}.zip; \
    unzip "/tmp/LanguageTool-${LT_VERSION}.zip"; \
    cd "/languagetool-omegat-${LT_VERSION}"; ./gradlew :languagetool-server:installDist -x check -x test ; \
    mkdir /languagetool; cp -r languagetool-server/build/install/languagetool-server/* /languagetool/; \
    rm "/tmp/LanguageTool-${LT_VERSION}.zip" 

FROM base

RUN set -eux; \
    apt update && apt install -y -qq tini xmlstarlet fasttext gosu wget unzip

RUN set -eux; \
    groupmod --gid 783 --new-name languagetool users; \
    adduser --system --uid 783 --gid 783 --no-create-home languagetool 

COPY --from=prepare /languagetool /languagetool
ENV langtool_fasttextBinary=/usr/bin/fasttext \
    download_ngrams_for_langs=none \
    MAP_UID=783 \
    MAP_GID=783 \
    LOG_LEVEL=INFO \
    LOGBACK_CONFIG=./logback.xml

WORKDIR /languagetool

COPY --chown=languagetool entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s CMD wget --quiet --post-data "language=en-US&text=a simple test" -O - http://localhost:8010/v2/check > /dev/null 2>&1  || exit 1
EXPOSE 8010

ENTRYPOINT ["/usr/bin/tini", "-g", "-e 143", "--", "/entrypoint.sh"]
