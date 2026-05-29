#!/bin/bash

echo "=========================================="
echo "     IMS 服务启动脚本"
echo "=========================================="

echo "[1/3] 配置 IMS IP 地址..."
ip addr show br-free5gc | grep -q "10.100.200.99" && echo "IMS IP已存在" || {
    ip addr add 10.100.200.99/24 dev br-free5gc && echo "已添加 IMS IP: 10.100.200.99"
}

echo "[2/3] 启动 kamailio..."
systemctl start kamailio.service
systemctl status kamailio.service --no-pager -l

echo "[3/3] 启动 free5gc-disable-offload..."
systemctl start free5gc-disable-offload.service
systemctl status free5gc-disable-offload.service --no-pager -l

echo "[4/4] 启动 free5gc-ue-routes..."
systemctl start free5gc-ue-routes.service
systemctl status free5gc-ue-routes.service --no-pager -l

echo "=========================================="
echo "     IMS 服务启动完成!"
echo "=========================================="
systemctl is-active kamailio.service free5gc-disable-offload.service free5gc-ue-routes.service