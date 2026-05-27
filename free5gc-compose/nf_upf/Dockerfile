FROM free5gc/base AS my-base

RUN git clone https://github.com/free5gc/go-gtp5gnl.git && mkdir "go-gtp5gnl/bin" && \
    cd "go-gtp5gnl/cmd/gogtp5g-tunnel" &&  go build -o "${GOPATH}/gtp5g-tunnel" . && \
    cd -
FROM bitnami/minideb:trixie

LABEL description="free5GC open source 5G Core Network" \
    version="Stage 3"

ENV F5GC_MODULE=upf
ENV DEBIAN_FRONTEND=noninteractive
ARG DEBUG_TOOLS

# Keep Debian's default HTTP mirrors. In proxied environments the forced HTTPS
# rewrite can fail certificate validation and break apt during image builds.

# Install debug tools ~ 100MB (if DEBUG_TOOLS is set to true)
RUN if [ "$DEBUG_TOOLS" = "true" ] ; then apt-get update && apt-get install -y vim strace net-tools iputils-ping curl netcat tcpdump; fi

# Install UPF dependencies
# Note: bitnami/minideb ships a musl-compiled /sbin/tini which cannot run on Debian (glibc).
# Install tini via apt (glibc-compiled) and overwrite the broken musl binary.
RUN apt-get update \
    && apt-get install -y tini libmnl0 libyaml-0-2 iproute2 iptables \
    && ln -sf /usr/bin/tini /sbin/tini \
    && apt-get clean

# Set working dir
WORKDIR /free5gc
RUN mkdir -p config/ log/

# Copy the UPF binary built on the host. Building this inside Docker is flaky in
# this environment because Go module fetches intermittently fail TLS handshakes.
COPY base/free5gc/bin/upf ./upf
COPY --from=my-base /go/gtp5g-tunnel ./gtp5g-tunnel

# Config files volume
VOLUME [ "/free5gc/config" ]
