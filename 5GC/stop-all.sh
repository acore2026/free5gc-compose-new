#!/bin/bash

COMPOSE_DIR="/home/core"

echo "=========================================="
echo "     Free5GC + IMS 一键停止脚本"
echo "=========================================="

echo "[1/2] 停止IMS服务..."
systemctl stop free5gc-ue-routes.service 2>/dev/null
systemctl stop free5gc-disable-offload.service 2>/dev/null
systemctl stop kamailio.service 2>/dev/null
echo "IMS服务已停止"

echo "[2/2] 停止5GC容器..."
cd "$COMPOSE_DIR"
docker-compose down

echo "=========================================="
echo "     所有服务已停止!"
echo "=========================================="
docker ps -a --format "table {{.Names}}\t{{.Status}}" | head -5