#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="/home/core"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL=7

step() { echo -e "${BLUE}[$1/$TOTAL] $2${NC}"; }
ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

echo "=========================================="
echo "     Free5GC + IMS 一键启动脚本"
echo "=========================================="

step 1 "加载 Docker 镜像..."
cd "$SCRIPT_DIR"

docker load -i mongodb.tar || fail "mongodb 镜像加载失败"
docker tag free5gc/mongodb:backup mongo:4.4 || fail "mongodb 标签设置失败"
docker rmi free5gc/mongodb:backup 2>/dev/null || true

for nf in nrf udr pcf udm ausf nssf chf nef smf amf webui; do
  docker load -i ${nf}.tar || fail "${nf} 镜像加载失败"
  docker tag free5gc/${nf}:backup free5gc/${nf}:v4.2.1 || fail "${nf} 标签设置失败"
  docker rmi free5gc/${nf}:backup 2>/dev/null || true
done

docker load -i upf.tar || fail "upf 镜像加载失败"
docker tag free5gc/upf:backup free5gc/upf:v4.2.1.ac2 || fail "upf 标签设置失败"
docker rmi free5gc/upf:backup 2>/dev/null || true

ok "Docker 镜像加载完成"

step 2 "加载 gtp5g 内核模块..."
if lsmod | grep -q gtp5g; then
    rmmod gtp5g 2>/dev/null || true
fi
if [ -f /home/core/gtp5g/gtp5g.ko ]; then
    insmod /home/core/gtp5g/gtp5g.ko && ok "gtp5g 模块加载成功" || fail "gtp5g 模块加载失败"
else
    fail "未找到 gtp5g.ko"
fi

step 3 "启动 5GC 容器..."
cd "$COMPOSE_DIR"
docker-compose up -d || fail "Docker 容器启动失败"
ok "Docker 容器已启动"

echo -e "${YELLOW}  等待 MongoDB 就绪...${NC}"
for i in $(seq 1 30); do
    docker exec mongodb mongo --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1 && break
    sleep 2
done
ok "MongoDB 已就绪"

step 4 "清理 UE 上下文..."
docker exec mongodb mongo --quiet --eval "
db = db.getSiblingDB('free5gc');
var r1 = db.subscriptionData.contextData.amf3gppAccess.deleteMany({});
var r2 = db.subscriptionData.authenticationData.authenticationStatus.deleteMany({});
print('AMF上下文: 删除 ' + r1.deletedCount + ' 条');
print('认证状态: 删除 ' + r2.deletedCount + ' 条');
" || true
ok "UE 上下文已清理"

step 5 "配置网络环境..."
ip addr add 10.88.120.100/24 dev eth1 2>/dev/null || true
ip addr add 10.88.120.99/24 dev eth1 2>/dev/null || true
ip link set eth1 up
ip addr add 10.100.200.99/24 dev br-free5gc 2>/dev/null || true
ok "网络配置完成"

step 6 "部署 IMS 服务配置..."
cp "$SCRIPT_DIR/systemd/kamailio.service" /usr/lib/systemd/system/kamailio.service || fail "kamailio.service 复制失败"
cp "$SCRIPT_DIR/systemd/kamailio.cfg" /etc/kamailio/kamailio.cfg || fail "kamailio.cfg 复制失败"
cp "$SCRIPT_DIR/systemd/kamailio.default" /etc/default/kamailio || fail "kamailio.default 复制失败"

cp "$SCRIPT_DIR/systemd/free5gc-disable-offload" /usr/local/sbin/free5gc-disable-offload || fail "free5gc-disable-offload 复制失败"
cp "$SCRIPT_DIR/systemd/free5gc-disable-offload.service" /etc/systemd/system/free5gc-disable-offload.service || fail "free5gc-disable-offload.service 复制失败"

cp "$SCRIPT_DIR/systemd/free5gc-ue-routes.service" /etc/systemd/system/free5gc-ue-routes.service || fail "free5gc-ue-routes.service 复制失败"

systemctl daemon-reload
ok "IMS 服务配置部署完成"

step 7 "启动 IMS 服务..."
systemctl start free5gc-ue-routes.service || fail "free5gc-ue-routes 启动失败"
ok "free5gc-ue-routes"
systemctl start kamailio.service || fail "kamailio 启动失败"
ok "kamailio"
systemctl start free5gc-disable-offload.service || fail "free5gc-disable-offload 启动失败"
ok "free5gc-disable-offload"

echo ""
echo "=========================================="
echo -e "${GREEN}     所有服务启动完成!${NC}"
echo "=========================================="
echo ""
echo "=== Docker 容器状态 ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "=== IMS 服务状态 ==="
systemctl is-active kamailio.service free5gc-disable-offload.service free5gc-ue-routes.service