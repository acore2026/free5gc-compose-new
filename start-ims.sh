#!/bin/bash
# IMS Startup Script for Free5GC

echo "Starting IMS Service..."

# Stop existing kamailio if running
sudo systemctl stop kamailio 2>/dev/null
sudo pkill -9 kamailio 2>/dev/null

sleep 1

# Start Kamailio IMS with custom config
sudo kamailio -f /etc/kamailio/kamailio-ims.cfg -DD -E -P /var/run/kamailio/kamailio.pid

sleep 2

# Check if IMS is running
if netstat -tuln | grep -q "10.88.120.99:5060"; then
    echo "✓ IMS Service Started Successfully"
    echo "  P-CSCF: 10.88.120.99:5060"
    echo "  Domain: ims.free5gc.org"
    
    # Show kamailio processes
    echo "  Processes: $(ps aux | grep kamailio | grep -v grep | wc -l)"
else
    echo "✗ IMS Service Failed to Start"
    exit 1
fi

echo ""
echo "IMS Configuration:"
echo "  - DNN: ims"
echo "  - P-CSCF IP: 10.88.120.99"
echo "  - DNS: 10.88.120.99"
echo "  - SIP Port: 5060"
echo ""
echo "Usage:"
echo "  - UE will register to IMS after PDU Session establishment"
echo "  - IMS supports REGISTER, INVITE, BYE, ACK methods"
echo ""