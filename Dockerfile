FROM debian:latest
LABEL maintainer "publicarray"
LABEL description "chrony is a versatile implementation of the Network Time Protocol (NTP)"
ENV REVISION 1

ENV CHRONY_BUILD_DEPS make tar wget gcc libcap-dev libseccomp-dev libedit-dev
RUN apt-get update \
    && apt-get install -y $CHRONY_BUILD_DEPS \
    && rm -rf /var/lib/apt/lists/*

# https://chrony.tuxfamily.org/news.html
ENV CHRONY_VERSION 3.5
ENV CHRONY_DOWNLOAD_URL "https://download.tuxfamily.org/chrony/chrony-${CHRONY_VERSION}.tar.gz"
ENV CHRONY_SHA256 4e02795b1260a4ec51e6ace84149036305cc9fc340e65edb9f8452aa611339b5
ENV TZDATA_VERSION 2018e

RUN set -x && \
    mkdir -p /tmp && \
    cd /tmp && \
    wget -O chrony.tar.gz $CHRONY_DOWNLOAD_URL && \
    echo "${CHRONY_SHA256} *chrony.tar.gz" | sha256sum -c - && \
    tar xzf chrony.tar.gz && \
    rm -f chrony.tar.gz && \
    cd chrony-${CHRONY_VERSION} && \
    ./configure --enable-scfilter --with-user _chrony \
    setenv CFLAGS "-O2 -flto -fPIE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -fstack-protector-strong -Wformat -Werror=format-security" \
    setenv LDFLAGS "-Wl,-z,now -Wl,-z,relro" && \
    make && \
    make quickcheck && \
    make install

#------------------------------------------------------------------------------#
FROM debian:latest

ENV CHRONY_RUN_DEPS libcap2 libseccomp2 libedit2 tzdata

RUN apt-get update \
    && apt-get install -y $CHRONY_RUN_DEPS \
    && rm -rf /var/lib/apt/lists/*

COPY --from=0 /usr/local/sbin/chronyd /usr/local/sbin/chronyd
COPY --from=0 /usr/local/bin/chronyc /usr/local/bin/chronyc

COPY chrony.conf /etc/chrony.conf

EXPOSE 123/udp

COPY entrypoint.sh /

RUN chronyd --version

HEALTHCHECK --interval=60s --timeout=5s CMD chronyc tracking > /dev/null

ENTRYPOINT ["/entrypoint.sh"]

# CMD ["--", "-d", "-F", "1", "-s"]
# CMD ["--", "-d", "-F", "1", "-s", "-m", "-P" "1"]
