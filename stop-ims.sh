#!/bin/bash
# IMS Stop Script

echo "Stopping IMS Service..."

sudo systemctl stop kamailio 2>/dev/null
sudo pkill -9 kamailio 2>/dev/null

sleep 1

if ! netstat -tuln | grep -q "10.88.120.99:5060"; then
    echo "✓ IMS Service Stopped Successfully"
else
    echo "✗ IMS Service Still Running"
    exit 1
fi