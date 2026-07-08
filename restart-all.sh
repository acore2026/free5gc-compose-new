#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL=7

step() { echo -e "${BLUE}[$1/$TOTAL] $2${NC}"; }
ok() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

echo "=========================================="
echo "     核心网重启脚本"
echo "=========================================="

step 1 "停止 IMS 服务..."
systemctl stop free5gc-ue-routes.service 2>/dev/null || true
systemctl stop free5gc-disable-offload.service 2>/dev/null || true
systemctl stop kamailio.service 2>/dev/null || true
ok "IMS 服务已停止"

step 2 "停止 Docker 容器..."
docker-compose down || fail "Docker 容器停止失败"
ok "Docker 容器已停止"

step 3 "加载 gtp5g 内核模块..."
if lsmod | grep -q gtp5g; then
    echo -e "${YELLOW}  移除旧 gtp5g 模块...${NC}"
    if ! rmmod gtp5g 2>/dev/null; then
        echo -e "${YELLOW}  警告: 无法移除旧模块，可能正在使用中${NC}"
    fi
fi

GTP5G_KO="/home/core/gtp5g/gtp5g.ko"
GTP5G_DIR="/home/core/gtp5g"
KERNEL_VER=$(uname -r)

if [ ! -f "$GTP5G_KO" ]; then
    fail "未找到 gtp5g.ko 文件"
fi

MODULE_VER=$(modinfo "$GTP5G_KO" 2>/dev/null | grep "^vermagic:" | awk '{print $2}')
if [ "$MODULE_VER" != "$KERNEL_VER" ]; then
    echo -e "${YELLOW}  模块版本不匹配 (模块: $MODULE_VER, 内核: $KERNEL_VER)${NC}"
    echo -e "${YELLOW}  正在重新编译 gtp5g 模块...${NC}"
    if ! make -C "$GTP5G_DIR" clean >/dev/null 2>&1; then
        echo -e "${YELLOW}  警告: make clean 失败，继续尝试编译${NC}"
    fi
    if make -C "$GTP5G_DIR" 2>&1 | grep -q "Error"; then
        echo -e "${RED}  详细错误信息:${NC}"
        make -C "$GTP5G_DIR" 2>&1 | tail -20
        fail "gtp5g 模块编译失败"
    fi
    ok "gtp5g 模块编译成功"
fi

if insmod "$GTP5G_KO"; then
    ok "gtp5g 模块加载成功"
else
    echo -e "${RED}  详细错误信息:${NC}"
    dmesg | tail -10 | grep -i gtp || true
    fail "gtp5g 模块加载失败 (内核: $(uname -r))"
fi

step 4 "启动 Docker 容器..."
docker-compose up -d || fail "Docker 容器启动失败"
ok "Docker 容器已启动"

echo -e "${YELLOW}  等待 MongoDB 就绪...${NC}"
for i in $(seq 1 30); do
    docker exec mongodb mongo --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1 && break
    sleep 2
done
ok "MongoDB 已就绪"

step 5 "清理 UE 上下文..."
docker exec mongodb mongo --quiet --eval "
db = db.getSiblingDB('free5gc');
var r1 = db.subscriptionData.contextData.amf3gppAccess.deleteMany({});
var r2 = db.subscriptionData.authenticationData.authenticationStatus.deleteMany({});
print('AMF上下文: 删除 ' + r1.deletedCount + ' 条');
print('认证状态: 删除 ' + r2.deletedCount + ' 条');
" || true
ok "UE 上下文已清理"

step 6 "配置网络环境..."
ip addr add 10.88.120.100/24 dev eth1 2>/dev/null || true
ip addr add 10.88.120.99/24 dev eth1 2>/dev/null || true
ip link set eth1 up
ip addr add 10.100.200.99/24 dev br-free5gc 2>/dev/null || true
ok "网络配置完成"

step 7 "启动 IMS 服务..."
systemctl restart free5gc-ue-routes.service || fail "free5gc-ue-routes 启动失败"
ok "free5gc-ue-routes"
systemctl restart kamailio.service || fail "kamailio 启动失败"
ok "kamailio"
systemctl restart free5gc-disable-offload.service || fail "free5gc-disable-offload 启动失败"
ok "free5gc-disable-offload"

echo ""
echo "=========================================="
echo -e "${GREEN}     核心网重启完成!${NC}"
echo "=========================================="
systemctl is-active kamailio.service free5gc-disable-offload.service free5gc-ue-routes.service