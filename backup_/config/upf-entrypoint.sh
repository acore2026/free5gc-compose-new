#!/bin/sh
# 配置NAT规则
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -I FORWARD 1 -j ACCEPT

# 启动UPF
exec ./upf -c ./config/upfcfg.yaml
