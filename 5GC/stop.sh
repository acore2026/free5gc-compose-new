#!/bin/bash

COMPOSE_DIR="/home/core"

echo "停止并删除所有5GC容器..."
cd "$COMPOSE_DIR"
docker-compose down

echo "所有容器已停止并删除"