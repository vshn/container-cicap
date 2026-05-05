FROM ubuntu:26.04@sha256:f3d28607ddd78734bb7f71f117f3c6706c666b8b76cbff7c9ff6e5718d46ff64 AS builder

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y autoconf curl build-essential clamav clamav-daemon libarchive-dev libatomic1 libtool

WORKDIR /tmp
# renovate: datasource=github-tags depName=c-icap/c-icap-server
ENV C_ICAP_VERSION=0.6.4

RUN curl -L -o "c-icap.tar.gz" "https://github.com/c-icap/c-icap-server/archive/refs/tags/C_ICAP_${C_ICAP_VERSION}.tar.gz" && \
    mkdir c-icap && \
    tar -xzf c-icap.tar.gz --strip-components=1 -C c-icap && \
    cd c-icap && \
    chmod +x RECONF && \
    ./RECONF && \
    automake && \
    ./configure --prefix=/usr/local/c-icap --enable-large-files && \
    make && make install

# renovate: datasource=github-tags depName=darold/squidclamav
ENV SQUIDCLAMAV_VERSION=7.4

RUN curl -L -o "squidclamav.tar.gz" "https://github.com/darold/squidclamav/archive/refs/tags/v${SQUIDCLAMAV_VERSION}.tar.gz" && \
    mkdir squidclamav && \
    tar -xzf squidclamav.tar.gz  --strip-components=1 -C squidclamav && \
    cd squidclamav && \
    ./configure --prefix=/usr/local/squidclamav --with-c-icap=/usr/local/c-icap && \
    make && make install

FROM ubuntu:26.04@sha256:f3d28607ddd78734bb7f71f117f3c6706c666b8b76cbff7c9ff6e5718d46ff64 AS server

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y libarchive13 libatomic1 netcat-openbsd gettext && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/c-icap /usr/local/c-icap
COPY --from=builder /usr/local/squidclamav /usr/local/squidclamav

RUN echo "/usr/local/c-icap/lib" > /etc/ld.so.conf.d/c-icap.conf && ldconfig
ENV PATH="/usr/local/c-icap/bin:${PATH}"

COPY config/c-icap.conf /usr/local/c-icap/etc/c-icap.conf
COPY config/squidclamav.conf /usr/local/c-icap/etc/squidclamav.conf.template

RUN mkdir -p /run/c-icap && \
    chgrp -R 0 /run/c-icap /usr/local/c-icap/etc && \
    chmod -R g=u /run/c-icap /usr/local/c-icap/etc

ENV CLAMD_MAXSIZE=5M
ENV CLAMD_HOST=clamav
ENV CLAMD_PORT=3310
ENV CLAMD_TIMEOUT=1
ENV CLAMD_ENABLE_LIBARCHIVE=0
ENV CLAMD_BANMAXSIZE=2M

COPY --chmod=0755 entrypoint.sh /entrypoint.sh

EXPOSE 1344

ENTRYPOINT ["/entrypoint.sh"]
CMD ["-N", "-S", "-d", "5"]
