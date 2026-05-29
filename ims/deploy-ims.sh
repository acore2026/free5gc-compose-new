#!/bin/bash
# IMS Deployment Script for Free5GC

echo "========================================"
echo "IMS (Kamailio P-CSCF) Deployment"
echo "========================================"

cd /home/core/ims

# Check if core_privnet exists
if ! docker network ls | grep -q "core_privnet"; then
    echo "Error: core_privnet network not found"
    echo "Please ensure Free5GC is running first"
    exit 1
fi

# Pull Kamailio image if needed
echo "Checking Kamailio image..."
docker pull kamailio/kamailio:5.5.4

# Start IMS container
echo "Starting IMS (P-CSCF)..."
docker-compose -f docker-compose-ims.yaml up -d

sleep 3

# Check if IMS is running
if docker ps | grep -q "ims-kamailio"; then
    echo "✓ IMS Started Successfully"
    echo ""
    echo "IMS Configuration:"
    echo "  - P-CSCF IP: 10.100.200.99"
    echo "  - SIP Port: 5060 (UDP/TCP)"
    echo "  - Domain: ims.free5gc.org"
    echo ""
    
    # Update SMF config with correct P-CSCF address
    echo "Updating SMF P-CSCF configuration..."
    
    docker exec smf sed -i 's/ipv4: 10.88.120.99/ipv4: 10.100.200.99/g' /free5gc/config/smfcfg.yaml
    docker exec smf sed -i 's/ipv6: 2001:4860:4860::8888/ipv6: ::1/g' /free5gc/config/smfcfg.yaml
    
    echo "✓ SMF config updated"
    echo ""
    echo "Note: You may need to restart SMF for changes to take effect:"
    echo "  docker restart smf"
    echo ""
    echo "Next steps:"
    echo "  1. Restart UE to trigger IMS PDU Session"
    echo "  2. UE should receive P-CSCF address via PCO"
    echo "  3. UE will register to IMS domain"
else
    echo "✗ IMS Failed to start"
    docker-compose -f docker-compose-ims.yaml logs
    exit 1
fi

echo "========================================"