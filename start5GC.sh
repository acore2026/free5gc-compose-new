#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START5GC_DIR="$SCRIPT_DIR/start5GC"

echo "========================================="
echo "   Free5GC 一键启动脚本"
echo "========================================="

echo "[1/3] 检查镜像..."
if ! docker images | grep -q "free5gc_local/amf"; then
    echo "  -> 导入镜像中..."
    docker load -i "$START5GC_DIR/images/free5gc-images.tar"
    docker load -i "$START5GC_DIR/images/mongo-image.tar"
    echo "  -> 镜像导入完成"
else
    echo "  -> 镜像已存在"
fi

echo "[2/3] 启动核心网..."
cd "$START5GC_DIR"
docker-compose up -d

echo "[3/3] 等待服务启动..."
sleep 5

echo ""
echo "========================================="
echo "   启动完成！"
echo "========================================="
echo "容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAMES|amf|smf|upf|nrf|udm|udr|ausf|pcf|nssf|nef|chf|webui|mongodb"
echo ""
echo "WebUI: http://localhost:5000"
echo "AMF: 10.88.120.100:38412/sctp"