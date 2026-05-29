#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="/home/core"

source "$SCRIPT_DIR/init_env.sh"

echo "=========================================="
echo "     Free5GC + IMS 一键启动脚本"
echo "=========================================="

echo "[1/4] 加载Docker镜像..."
cd "$SCRIPT_DIR"

docker load -i mongodb.tar
docker tag free5gc/mongodb:backup mongo:4.4
docker rmi free5gc/mongodb:backup 2>/dev/null

for nf in nrf udr pcf udm ausf nssf chf nef smf amf webui; do
  docker load -i ${nf}.tar
  docker tag free5gc/${nf}:backup free5gc/${nf}:v4.2.1
  docker rmi free5gc/${nf}:backup 2>/dev/null
done

docker load -i upf.tar
docker tag free5gc/upf:backup free5gc/upf:v4.2.1.ac2
docker rmi free5gc/upf:backup 2>/dev/null

echo "[2/4] 启动5GC容器 (docker-compose)..."
cd "$COMPOSE_DIR"
docker-compose up -d

echo "等待容器启动..."
sleep 5

echo "[3/4] 部署IMS服务配置..."

echo "部署 kamailio 服务..."
cp "$SCRIPT_DIR/systemd/kamailio.service" /usr/lib/systemd/system/kamailio.service
cp "$SCRIPT_DIR/systemd/kamailio.cfg" /etc/kamailio/kamailio.cfg
cp "$SCRIPT_DIR/systemd/kamailio.default" /etc/default/kamailio
systemctl daemon-reload

echo "部署 free5gc-disable-offload 服务..."
cp "$SCRIPT_DIR/systemd/free5gc-disable-offload" /usr/local/sbin/free5gc-disable-offload
cp "$SCRIPT_DIR/systemd/free5gc-disable-offload.service" /etc/systemd/system/free5gc-disable-offload.service

echo "部署 free5gc-ue-routes 服务..."
cp "$SCRIPT_DIR/systemd/free5gc-ue-routes.service" /etc/systemd/system/free5gc-ue-routes.service

systemctl daemon-reload

echo "[4/4] 启动IMS服务..."

echo "启动 kamailio..."
systemctl start kamailio.service
systemctl status kamailio.service --no-pager -l | grep -E "(Active|Loaded)"

echo "启动 free5gc-disable-offload..."
systemctl start free5gc-disable-offload.service
systemctl status free5gc-disable-offload.service --no-pager -l | grep -E "(Active|Loaded)"

echo "启动 free5gc-ue-routes..."
systemctl start free5gc-ue-routes.service
systemctl status free5gc-ue-routes.service --no-pager -l | grep -E "(Active|Loaded)"

echo "=========================================="
echo "     所有服务启动完成!"
echo "=========================================="
echo ""
echo "=== Docker容器状态 ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "=== IMS服务状态 ==="
systemctl is-active kamailio.service free5gc-disable-offload.service free5gc-ue-routes.service