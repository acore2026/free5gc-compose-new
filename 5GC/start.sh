#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="/home/core"

echo "=========================================="
echo "     Free5GC 核心网容器启动脚本"
echo "=========================================="

echo "[1/2] 加载镜像..."
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

echo "[2/2] 启动容器 (docker-compose)..."
cd "$COMPOSE_DIR"
docker-compose up -d

echo "=========================================="
echo "     所有容器启动完成!"
echo "=========================================="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"