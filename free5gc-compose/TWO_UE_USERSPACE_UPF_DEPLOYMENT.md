# Two-UE Userspace UPF Deployment Guide

## Scope

This guide deploys the local `docker-compose-build.yaml` free5GC stack with:

- one userspace-forwarder UPF
- two simulated gNB containers
- two simulated UE containers
- one PDU session per UE
- UE-to-UE cross-ping over the 5G user plane

The current Go RAN implementation keeps a single UE context inside each gNB process. For two concurrent UEs, run one gNB per UE:

- `ueransim` / `gNB1` at `10.100.200.17` for `ue`
- `ueransim2` / `gNB2` at `10.100.200.18` for `ue2`

## Topology

```text
ue  10.60.0.1/24
  -> gNB1 10.100.200.17
  -> UPF  10.100.200.3 userspace forwarder / upfusr0
  -> gNB2 10.100.200.18
  -> ue2 10.60.0.2/24
```

The reverse path mirrors this route.

## Prerequisites

- Docker Engine and Docker Compose v2
- `/dev/net/tun` available on the host
- local images for `docker-compose-build.yaml` built, or network access to build them
- repo root as the working directory

```bash
cd /root/proj/go/free5gc-compose
```

## Build Required Images

Skip this section if the local images already exist.

Build the services needed for the core, gNB, and UE. This intentionally omits `adaptive-qos-ui`; it is not required for this deployment.

```bash
docker compose -f docker-compose-build.yaml build \
  free5gc-upf db free5gc-nrf free5gc-amf free5gc-ausf free5gc-nssf \
  free5gc-pcf free5gc-smf free5gc-udm free5gc-udr free5gc-webui \
  free5gc-chf free5gc-nef free5gc-tngf ueransim ue
```

## Start Core, UPF, gNB1, and UE1

`docker-compose-build.yaml` defaults the UPF config mount to `config/upfcfg-userspace-adaptive.yaml`, which uses the userspace forwarder.

```bash
docker compose -f docker-compose-build.yaml up --no-build -d \
  db free5gc-nrf free5gc-amf free5gc-ausf free5gc-nssf free5gc-pcf \
  free5gc-smf free5gc-udm free5gc-udr free5gc-upf free5gc-webui \
  free5gc-chf free5gc-nef free5gc-tngf ueransim ue
```

Confirm the UPF is in userspace mode:

```bash
docker logs upf 2>&1 | grep 'starting Gtpu Forwarder'
docker exec upf ip -br addr show upfusr0
```

Expected:

```text
starting Gtpu Forwarder [userspace]
upfusr0 UNKNOWN ...
```

Wait until UE1 has a tunnel address:

```bash
docker exec ue ip -br addr show type tun
```

Expected:

```text
uesimtun0 UNKNOWN 10.60.0.1/24 ...
```

## Provision UE2 Subscriber

Clone the existing UE1 subscription data to UE2. This assumes UE1 is `imsi-208930000000001` and UE2 will be `imsi-208930000000002`.

```bash
docker exec mongodb mongo --quiet free5gc --eval '
var from = "imsi-208930000000001";
var to = "imsi-208930000000002";
var copied = 0;
db.getCollectionNames().forEach(function(name) {
  var c = db.getCollection(name);
  var docs = c.find({ueId: from}).toArray();
  if (docs.length) {
    c.deleteMany({ueId: to});
    docs.forEach(function(d) {
      delete d._id;
      d.ueId = to;
      c.insert(d);
      copied++;
    });
  }
});
print("copied=" + copied);
'
```

Expected:

```text
copied=10
```

## Create gNB2 and UE2 Runtime Configs

Create a second gNB config on `10.100.200.18`:

```bash
sed \
  -e 's/name: gNB1/name: gNB2/' \
  -e 's/gnbId: "000102"/gnbId: "000103"/' \
  -e 's/nci: "0x000000010"/nci: "0x000000020"/' \
  -e 's/10\.100\.200\.17/10.100.200.18/g' \
  config/gnbcfg-sidecar.yaml >/tmp/gnbcfg-2.yaml
```

Create a second UE config that uses UE2's IMSI and points to gNB2:

```bash
sed \
  -e 's/imsi-208930000000001/imsi-208930000000002/' \
  -e 's/10\.100\.200\.17:38412/10.100.200.18:38412/' \
  config/uecfg.yaml >/tmp/uecfg-2.yaml
```

Quick check:

```bash
grep -nE 'supi|10\.100\.200' /tmp/uecfg-2.yaml
```

Expected:

```text
2:supi: "imsi-208930000000002"
26:  - 10.100.200.18:38412
```

## Start gNB2 and UE2

Remove stale manual containers if they exist:

```bash
docker rm -f ue2 ueransim2 2>/dev/null || true
```

Start `ueransim2`:

```bash
docker run -d \
  --name ueransim2 \
  --network free5gc-compose_privnet \
  --ip 10.100.200.18 \
  --network-alias gnb2.free5gc.org \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -v /tmp/gnbcfg-2.yaml:/ueransim/config/gnbcfg.yaml:ro \
  --entrypoint ./nr-gnb \
  free5gc-compose-ueransim \
  -config ./config/gnbcfg.yaml
```

Confirm NG setup succeeded:

```bash
docker logs --tail 40 ueransim2
```

Expected log signal:

```text
received NGAP successful outcome
```

Start `ue2`:

```bash
docker run -d \
  --name ue2 \
  --network free5gc-compose_privnet \
  --network-alias ue2.free5gc.org \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -v /tmp/uecfg-2.yaml:/ueransim/config/uecfg.yaml:ro \
  -v /root/proj/go/free5gc-compose/config/adaptive-qos-sidecar.yaml:/ueransim/config/adaptive-qos-sidecar.yaml:ro \
  -e UPF_HOST=upf \
  -e UPF_PORT=9082 \
  -e CORE_READY_TIMEOUT=30 \
  -e CORE_READY_INTERVAL=2 \
  -e UE_START_DELAY=0 \
  --entrypoint ./entrypoint-ue-sidecar.sh \
  free5gc-compose-ue \
  ./nr-ue -config ./config/uecfg.yaml
```

Confirm UE2 registration and PDU session:

```bash
docker logs --tail 80 ue2 | grep -E 'Registration Accept|PDU Session Establishment Accept|configuring TUN'
docker exec ue2 ip -br addr show type tun
```

Expected:

```text
PDU Session Establishment Accept received ... ip=10.60.0.2
uesimtun0 UNKNOWN 10.60.0.2/24 ...
```

## Verify Running Containers

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}' \
  | grep -E '^(NAMES|mongodb|nrf|amf|smf|upf|ueransim|ueransim2|ue|ue2|webui|ausf|udm|udr|pcf|nssf|chf|nef|tngf)'
```

Expected core signals:

- `upf` is `Up`
- `ueransim` and `ueransim2` are `Up`
- `ue` and `ue2` are `Up`

## UE Cross-Ping Test

Ping from UE1 to UE2:

```bash
docker exec ue ping -I uesimtun0 -c 3 -W 2 10.60.0.2
```

Ping from UE2 to UE1:

```bash
docker exec ue2 ping -I uesimtun0 -c 3 -W 2 10.60.0.1
```

Expected success:

```text
2 packets transmitted, 2 received, 0% packet loss
```

You may also see an ICMP redirect from the UPF:

```text
From 10.100.200.3 icmp_seq=2 Redirect Host(New nexthop: 10.60.0.x)
```

That redirect is expected in this local topology. `10.100.200.3` is the UPF container IP.

## Confirm Cross-Ping Traverses UPF

Check the UE routes:

```bash
docker exec ue ip route
docker exec ue2 ip route
```

Expected on each UE:

```text
10.60.0.0/24 dev uesimtun0 ...
```

Check the UPF route:

```bash
docker exec upf ip route
```

Expected:

```text
10.60.0.0/16 dev upfusr0 proto static
```

Measure `upfusr0` counters around a cross-ping:

```bash
docker exec upf ip -s link show upfusr0
docker exec ue ping -I uesimtun0 -c 3 -W 2 10.60.0.2
docker exec upf ip -s link show upfusr0
```

The RX/TX packet counters on `upfusr0` should increase.

## Packet Path

For `ue -> ue2`:

```text
ue uesimtun0
  -> UE PDCP/RLC/RLS
  -> gNB1
  -> GTP-U to UPF N3 10.100.200.3:2152
  -> UPF userspace PDR match
  -> upfusr0
  -> UPF downlink PDR match for 10.60.0.2
  -> GTP-U to gNB2 10.100.200.18:2152
  -> gNB2 PDCP/RLC/RLS
  -> ue2 uesimtun0
```

## Cleanup

Stop the manual second gNB and UE:

```bash
docker rm -f ue2 ueransim2
```

Stop the compose stack:

```bash
docker compose -f docker-compose-build.yaml down
```

