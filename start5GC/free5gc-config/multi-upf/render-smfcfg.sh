#!/bin/sh

set -eu

active_upf="${1:-UPF1}"

case "$active_upf" in
  UPF1)
    active_addr="upf1.free5gc.org"
    active_pool="10.60.0.0/16"
    ;;
  UPF2)
    active_addr="upf2.free5gc.org"
    active_pool="10.61.0.0/16"
    ;;
  UPF3)
    active_addr="upf3.free5gc.org"
    active_pool="10.62.0.0/16"
    ;;
  *)
    echo "unsupported ACTIVE_UPF: $active_upf" >&2
    exit 1
    ;;
esac

cat <<EOF
info:
  version: 1.0.7
  description: SMF configuration for a generic three-UPF topology

configuration:
  smfName: SMF
  sbi:
    scheme: http
    registerIPv4: smf.free5gc.org
    bindingIPv4: smf.free5gc.org
    port: 8000
    tls:
      key: cert/smf.key
      pem: cert/smf.pem
  serviceNameList:
    - nsmf-pdusession
    - nsmf-event-exposure
    - nsmf-oam
  snssaiInfos:
    - sNssai:
        sst: 1
        sd: 010203
      dnnInfos:
        - dnn: internet
          dns:
            ipv4: 8.8.8.8
            ipv6: 2001:4860:4860::8888
  plmnList:
    - mcc: 208
      mnc: 93
  locality: area1
  pfcp:
    nodeID: smf.free5gc.org
    listenAddr: smf.free5gc.org
    externalAddr: smf.free5gc.org
    heartbeatInterval: 5s
  userplaneInformation:
    upNodes:
      gNB1:
        type: AN
      UPF:
        type: UPF
        nodeID: ${active_addr}
        addr: ${active_addr}
        sNssaiUpfInfos:
          - sNssai:
              sst: 1
              sd: 010203
            dnnUpfInfoList:
              - dnn: internet
                pools:
                  - cidr: ${active_pool}
        interfaces:
          - interfaceType: N3
            endpoints:
              - ${active_addr}
            networkInstances:
              - internet
    links:
      - A: gNB1
        B: UPF
  t3591:
    enable: true
    expireTime: 16s
    maxRetryTimes: 3
  t3592:
    enable: true
    expireTime: 16s
    maxRetryTimes: 3
  nrfUri: http://nrf.free5gc.org:8000
  nrfCertPem: cert/nrf.pem
  urrPeriod: 10
  urrThreshold: 1000
  requestedUnit: 1000

logger:
  enable: true
  level: info
  reportCaller: false
EOF
