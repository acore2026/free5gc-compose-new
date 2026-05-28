#!/bin/bash

echo "停止 IMS 服务..."

systemctl stop free5gc-ue-routes.service 2>/dev/null
systemctl stop free5gc-disable-offload.service 2>/dev/null
systemctl stop kamailio.service 2>/dev/null

echo "IMS 服务已停止"
systemctl is-active kamailio.service free5gc-disable-offload.service free5gc-ue-routes.service 2>/dev/null || echo "全部已停止"