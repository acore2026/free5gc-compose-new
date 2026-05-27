# UE to UPF N3 Ping

## Purpose

This note captures the process used to verify that a simulated UE can ping the UPF N3 interface inside this `free5gc-compose` deployment.

## Environment

- Repo path: `/root/proj/go/free5gc-compose`
- Stack file: `docker-compose-build.yaml`
- Running containers included `upf`, `amf`, `smf`, `ueransim` (gNB), and `ue` (UE)
- The Go implementation of UERANSIM is used, orchestrated as separate containers.

## Relevant Addresses

- UPF container IP on `privnet`: `10.100.200.3`
- gNB container IP on `privnet`: `10.100.200.17`
- UE container IP on `privnet`: `10.100.200.14`
- UE tunnel interface 1: `uesimtun0` with IP `10.60.0.1/16`

The UPF N3 address comes from `config/upfcfg.yaml`, where the N3 interface is configured as `upf.free5gc.org`.

## Validation Steps

### 1. Confirm the core is running

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

Expected:
- `upf`, `amf`, `smf`, `ueransim`, and `ue` should all be `Up`

### 2. Confirm UE tunnels exist

```bash
docker exec ue ip addr
```

Expected:
- `uesimtun0` present with `10.60.0.1/16`

### 3. Confirm the UPF N3-side IP

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' upf
```

### 4. Ping the UPF N3 interface from the first UE tunnel

```bash
docker exec ue ping -I uesimtun0 -c 4 10.100.200.3
```

## If the UE Is Not Already Running

If the `ue` container is not running, start it using:

```bash
docker compose -f docker-compose-build.yaml up -d ue
```

## Success Criteria

- UE registration completes successfully
- At least one `uesimtun` interface is created in `ue`
- `ping -I uesimtun0 -c 4 10.100.200.3` returns replies from the UPF


## Conclusion

The UE-to-UPF N3 connectivity test succeeded in this environment.
- `uesimtun0` to `10.100.200.3`: success, `0%` packet loss
- `uesimtun1` to `10.100.200.3`: partial success during the sample run
