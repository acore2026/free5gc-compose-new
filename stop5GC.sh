#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START5GC_DIR="$SCRIPT_DIR/start5GC"

echo "========================================="
echo "   Free5GC 停止脚本"
echo "========================================="

cd "$START5GC_DIR"
docker-compose down

echo ""
echo "核心网已停止"