FROM gcc:14.3.0 AS builder

LABEL maintainer="Free5GC <support@free5gc.org>"

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="$PATH:/cmake/bin"

ARG TARGET_ARCH=x86_64 
# TARGET_ARCH support : x86_64, aarch64(arm64)



# Install dependencies
RUN apt-get update \
    && apt-get install libsctp-dev lksctp-tools iproute2 make -y \
    && mkdir /cmake \
    && cd /cmake \
    && wget https://github.com/Kitware/CMake/releases/download/v4.1.2/cmake-4.1.2-linux-${TARGET_ARCH}.sh -O cmake_installer.sh \
    && chmod +x cmake_installer.sh \
    && ./cmake_installer.sh --skip-license \
    && cd .. \
    && git clone -b master -j `nproc` https://github.com/aligungr/UERANSIM \
    && cd ./UERANSIM \
    && make -j `nproc`

FROM golang:1.26 AS adaptive-qos-builder

WORKDIR /src
COPY base/free5gc/NFs/upf /src/upf
WORKDIR /src/upf
RUN go build -o /out/adaptive-qos-sidecar ./cmd/adaptive-qos-sidecar
RUN go build -o /out/adaptive-qos-client ./cmd/adaptive-qos-client


FROM bitnami/minideb:trixie

ENV DEBIAN_FRONTEND=noninteractive



# Install runtime dependencies + ping
RUN apt-get update \
    && apt-get install libsctp-dev lksctp-tools iproute2 iputils-ping procps psmisc -y \
    && apt-get clean

WORKDIR /ueransim

RUN mkdir -p config/ binder/
RUN mkdir -p /etc/iproute2
RUN touch /etc/iproute2/rt_tables

COPY --from=builder /UERANSIM/build/nr-gnb .
COPY --from=builder /UERANSIM/build/nr-ue .
COPY --from=builder /UERANSIM/build/nr-cli .
COPY --from=builder /UERANSIM/build/nr-binder binder/
COPY --from=builder /UERANSIM/build/libdevbnd.so binder/
COPY --from=adaptive-qos-builder /out/adaptive-qos-sidecar .
COPY --from=adaptive-qos-builder /out/adaptive-qos-client .
COPY ./ueransim/entrypoint-ue-sidecar.sh .
RUN chmod +x ./entrypoint-ue-sidecar.sh ./adaptive-qos-sidecar ./adaptive-qos-client

VOLUME [ "/ueransim/config" ]
