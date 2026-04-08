FROM ubuntu:24.04@sha256:cc925e589b7543b910fea57a240468940003fbfc0515245a495dd0ad8fe7cef1 AS builder

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl build-essential clamav clamav-daemon libarchive-dev libatomic1

WORKDIR /tmp

ENV C_ICAP_VERSION=0.6.4

RUN curl -L -o "c-icap.tar.gz" "https://sourceforge.net/projects/c-icap/files/c-icap/0.6.x/c_icap-${C_ICAP_VERSION}.tar.gz" && \
    mkdir c-icap && \
    tar -xzf c-icap.tar.gz --strip-components=1 -C c-icap && \
    cd c-icap && \
    ./configure --prefix=/usr/local/c-icap --enable-large-files && \
    make && make install

ENV SQUIDCLAMAV_VERSION=7.4

RUN curl -L -o "squidclamav.tar.gz" "https://github.com/darold/squidclamav/archive/refs/tags/v${SQUIDCLAMAV_VERSION}.tar.gz" && \
    mkdir squidclamav && \
    tar -xzf squidclamav.tar.gz  --strip-components=1 -C squidclamav && \
    cd squidclamav && \
    ./configure --prefix=/usr/local/squidclamav --with-c-icap=/usr/local/c-icap && \
    make && make install

FROM ubuntu:24.04@sha256:cc925e589b7543b910fea57a240468940003fbfc0515245a495dd0ad8fe7cef1 as server

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y libarchive13 libatomic1 netcat-openbsd gettext && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/c-icap /usr/local/c-icap
COPY --from=builder /usr/local/squidclamav /usr/local/squidclamav
 
# Add c-icap binaries and libs to PATH and LD_LIBRARY_PATH
ENV PATH="/usr/local/c-icap/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/c-icap/lib:${LD_LIBRARY_PATH}"

# Copy config
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
