#!/bin/bash
set -e

NF=${1:-amf}
TAG_SUFFIX=${2:-updatev3}

MOD_CACHE=go-mod-cache
BUILD_CACHE=go-build-cache
SRC_DIR=/home/core/free5gc-compose/base/free5gc
NF_DIR=/home/core/free5gc-compose/nf_${NF}

docker volume create ${MOD_CACHE} 2>/dev/null || true
docker volume create ${BUILD_CACHE} 2>/dev/null || true

echo "=== Step 1: Compile ${NF} binary with cached Go modules ==="
docker run --rm \
  --dns 8.8.8.8 --dns 8.8.4.4 \
  -v ${MOD_CACHE}:/go/pkg/mod \
  -v ${BUILD_CACHE}:/root/.cache/go-build \
  -v ${SRC_DIR}:/go/src/free5gc \
  -e GOPROXY=https://proxy.golang.org,direct \
  -w /go/src/free5gc \
  free5gc/base:latest \
  bash -c "git config --global --add safe.directory /go/src/free5gc && git config --global --add safe.directory /go/src/free5gc/NFs/${NF} && make ${NF}"

echo "=== Step 2: Copy binary, config, cert into host for image build ==="
TMPDIR=$(mktemp -d)
mkdir -p ${TMPDIR}/bin ${TMPDIR}/config ${TMPDIR}/cert

docker run --rm \
  -v ${MOD_CACHE}:/go/pkg/mod \
  -v ${SRC_DIR}:/go/src/free5gc \
  -w /go/src/free5gc \
  free5gc/base:latest \
  bash -c "cat bin/${NF}" > ${TMPDIR}/bin/${NF}

docker run --rm \
  -v ${SRC_DIR}:/go/src/free5gc \
  free5gc/base:latest \
  bash -c "tar -C /go/src/free5gc/cert -c ." | tar -C ${TMPDIR}/cert -x

docker run --rm \
  -v ${SRC_DIR}:/go/src/free5gc \
  free5gc/base:latest \
  bash -c "tar -C /go/src/free5gc/config -c ." | tar -C ${TMPDIR}/config -x

echo "=== Step 3: Build final image free5gc/${NF}:${TAG_SUFFIX} ==="
cat > ${TMPDIR}/Dockerfile <<'EOF'
FROM alpine:3.15
ARG F5GC_MODULE
RUN apk add --no-cache tini
WORKDIR /free5gc
RUN mkdir -p config/ log/ cert/
COPY bin/${F5GC_MODULE} ./
COPY cert/ ./cert/
COPY config/ ./config/
EOF

docker build --build-arg F5GC_MODULE=${NF} -t free5gc/${NF}:${TAG_SUFFIX} ${TMPDIR}

rm -rf ${TMPDIR}

echo "=== Done ==="
docker images free5gc/${NF}:${TAG_SUFFIX}