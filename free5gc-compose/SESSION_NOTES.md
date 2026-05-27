# Session Notes

## Host Facts

- Repo path: `/home/acore/proj/go/free5gc-compose`
- Host Docker CLI supports `docker compose` (V2).
- Host kernel: `6.8.0-106-generic` (Ubuntu 24.04)
- `gtp5g` kernel module: **Installed and available** (version `v0.9.16`).
- Result: **Full end-to-end 5G data session is working.**

## Local Repo Changes Made

- Patched Debian-based Dockerfiles to rewrite apt sources to HTTPS before package install.
- **Updated `docker-compose.yaml`**: Added `sysctls: [net.ipv4.ip_forward=1]` to the `free5gc-upf` service to enable NAT for UE traffic.

## Topology

### Full 5G Core (User Plane Supported)
Included: All services in `docker-compose.yaml`.
Requires: `gtp5g` kernel module on the host and `ip_forward` enabled in the UPF container.

## WebUI Credentials

- URL: `http://localhost:5000`
- Username: `admin`
- Password: `free5gc`

## Test UE / Subscriber Values

UE config used for data session:
- Mounted file: [`config/uecfg.yaml`](config/uecfg.yaml)
- SUPI: `imsi-208930000000001`
- DNN: `internet`
- S-NSSAI: `SST: 1, SD: 010203`

Subscriber provisioning:
- Provisioned manually via the **WebUI** (http://localhost:5000) or MongoDB script.
- Uses `OPC` auth data.
- Maps `imsi-208930000000001` to the `internet` DNN and slice `01010203`.

## Commands That Worked

### Start Full Stack
```bash
docker-compose up -d
```

### Trigger UE Registration & PDU Session
```bash
docker compose -f docker-compose-build.yaml up -d ue
```

### Verify User Plane Connectivity
Once the UE is registered and `uesimtun0` is created:
```bash
# Check interface
docker exec ue ip addr show uesimtun0
# Ping through 5G tunnel
docker exec ue ping -I uesimtun0 8.8.8.8
```

## Expected Success Signals

UE log:
- `Registration procedure... [SUCCESS]`
- `PDU Session establishment procedure... [SUCCESS]`
- `Connection setup for PDU session [1] is successful, TUN interface [uesimtun0] is up`

SMF log:
- `UPF(10.100.200.14) setup association`
- `HandlePDUSessionSMContextCreate`

## Failure Modes Resolved

- **`gtp5g` Version Mismatch**: UPF (v4.2.1) required `gtp5g` between `0.9.5` and `0.10.0`. Installed `v0.9.16`.
- **SMF Panic (`invalid argument to Intn`)**: Occurred when SMF attempted UPF selection before PFCP association was fully established. Fixed by ensuring UPF is healthy and associated.
- **User Plane Timeout**: Fixed by adding `net.ipv4.ip_forward=1` to the UPF container's sysctls.

## Current Conclusion

- The environment is fully capable of end-to-end 5G testing.
- End-to-end data traffic (UE -> gNB -> UPF -> Internet) is verified and working.
