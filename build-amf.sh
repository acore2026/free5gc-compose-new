#!/bin/bash
#
# build-amf.sh - 编译 AMF 源码并打包 Docker 镜像
#
# 用法:
#   ./build-amf.sh              # 使用默认 tag (自动递增 buildvXX)
#   ./build-amf.sh buildv18     # 指定 tag
#   ./build-amf.sh buildv18 -r  # 构建后重启 AMF 容器
#
# 说明:
#   宿主机已安装 Go 1.25.5, 在宿主机编译二进制可避免 Docker 容器内
#   DNS 解析失败问题。最终镜像复用上一次的 AMF 镜像作为 base
#   (已含 tini/certs/config 目录), 仅替换 amf 二进制, 无需联网。
#
set -e

PROJECT_DIR="/home/core/free5gc-compose-new"
AMF_SRC="$PROJECT_DIR/nf_amf/amf"
IMAGE_PREFIX="free5gc/amf"
RESTART=0

# 解析参数
TAG="${1:-}"
if [ "$2" = "-r" ] || [ "$3" = "-r" ]; then
    RESTART=1
fi

# 未指定 tag 时自动递增 buildvXX
if [ -z "$TAG" ]; then
    LATEST=$(docker images "${IMAGE_PREFIX}" --format '{{.Tag}}' \
        | grep -E '^buildv[0-9]+$' \
        | sed 's/buildv//' \
        | sort -n \
        | tail -1)
    NEXT=$((LATEST + 1))
    TAG="buildv${NEXT}"
fi

IMAGE="${IMAGE_PREFIX}:${TAG}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}"; exit 1; }
step() { echo -e "${BLUE}[$1] $2${NC}"; }

echo "=========================================="
echo "     AMF 镜像构建脚本"
echo "     目标镜像: ${IMAGE}"
echo "=========================================="

# --- Step 1: 宿主机编译二进制 ---
step "1/3" "宿主机编译 AMF 二进制..."
cd "$AMF_SRC"
echo -e "${YELLOW}  源码: $(pwd)${NC}"
echo -e "${YELLOW}  分支: $(git rev-parse --abbrev-ref HEAD)${NC}"
echo -e "${YELLOW}  提交: $(git log --oneline -1)${NC}"

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o amf-binary ./cmd/ \
    || fail "二进制编译失败"

SIZE=$(du -h amf-binary | cut -f1)
ok "编译成功 (amf-binary, ${SIZE})"

# --- Step 2: 确定 base 镜像 ---
step "2/3" "准备 Docker base 镜像..."
# 查找已有的最新 AMF 镜像作为 base (含 tini/certs)
BASE=$(docker images "${IMAGE_PREFIX}" --format '{{.Repository}}:{{.Tag}}' \
    | grep -vE "^${IMAGE_PREFIX}:<none>" \
    | grep -vE ":${TAG}$" \
    | head -1)

if [ -z "$BASE" ]; then
    echo -e "${YELLOW}  未找到已有 AMF 镜像, 使用 Dockerfile.build 完整构建...${NC}"
    cd "$PROJECT_DIR"
    docker build -t "$IMAGE" -f nf_amf/Dockerfile.build nf_amf/ \
        || fail "Docker 镜像构建失败"
else
    echo -e "${YELLOW}  base 镜像: ${BASE} (复用 tini/certs)${NC}"
    # 用已有镜像作为 base, 仅替换二进制 (无需联网)
    TMPDF=$(mktemp)
    cat > "$TMPDF" <<EOF
FROM ${BASE}
COPY amf-binary ./amf
EOF
    cd "$AMF_SRC"
    docker build -t "$IMAGE" -f "$TMPDF" . \
        || fail "Docker 镜像构建失败"
    rm -f "$TMPDF"
fi
ok "镜像构建成功: ${IMAGE}"

# --- Step 3: 验证 ---
step "3/3" "验证镜像..."
docker run --rm "$IMAGE" ./amf --help >/dev/null 2>&1 \
    && ok "二进制可正常运行" \
    || fail "二进制运行异常"

echo ""
echo "=========================================="
echo -e "${GREEN}  构建完成!${NC}"
echo "=========================================="
docker images "$IMAGE"

# --- 可选: 重启 AMF 容器 ---
if [ "$RESTART" = "1" ]; then
    echo ""
    echo -e "${BLUE}重启 AMF 容器...${NC}"
    cd "$PROJECT_DIR"
    # 更新 docker-compose.yaml 中的 image tag
    sed -i "s|image: ${IMAGE_PREFIX}:buildv[0-9]*|image: ${IMAGE}|" docker-compose.yaml
    ok "docker-compose.yaml 已更新为 ${TAG}"
    docker-compose up -d free5gc-amf \
        || fail "AMF 容器重启失败"
    ok "AMF 容器已重启"
    sleep 2
    docker ps --filter "name=amf" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
fi
