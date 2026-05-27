# free5GC compose

This repository is a docker compose version of [free5GC](https://github.com/acore2026/free5gc) for stage 3. It's inspired by [free5gc-docker-compose](https://github.com/calee0219/free5gc-docker-compose) and also reference to [docker-free5gc](https://github.com/abousselmi/docker-free5gc).

You can setup your own config in [config](./config) folder and [docker-compose.yaml](docker-compose.yaml)

## Prerequisites

- [GTP5G kernel module](https://github.com/free5gc/gtp5g): needed to run the UPF (Currently, UPF only supports GTP5G versions 0.9.5 (use git clone --branch v0.9.5 --depth 1 https://github.com/free5gc/gtp5g.git).)
- [Docker Engine](https://docs.docker.com/engine/install): needed to run the Free5GC containers
- [Docker Compose v2](https://docs.docker.com/compose/install): needed to bootstrap the free5GC stack

**Note: AVX for MongoDB**: some HW does not support MongoDB releases above`4.4` due to use of the new AVX instructions set. To verify if your CPU is compatible you can check CPU flags by running `grep avx /proc/cpuinfo`. A workaround is suggested [here](https://github.com/acore2026/free5gc-compose/issues/30#issuecomment-897627049).

## Start free5gc

Because we need to create tunnel interface, we need to use privileged container with root permission.

### Pull docker images from Docker Hub

```bash
docker compose pull
```

### [Optional] Build docker images from local sources

```bash
# Clone the project
git clone https://github.com/acore2026/free5gc-compose.git
cd free5gc-compose

# clone free5gc sources (including submodules like ueransim-go)
cd base
git clone --recursive -j `nproc` https://github.com/acore2026/free5gc.git
cd ..

# Build the local images
make all
docker compose -f docker-compose-build.yaml build
```

Note: If you have already cloned `base/free5gc` without `--recursive`, you can initialize the submodules (like `ueransim-go`) by running:
```bash
cd base/free5gc
git submodule update --init --recursive
cd ../..
```
# Alternatively you can build specific NF image e.g.:
make amf
docker compose -f docker-compose-build.yaml build free5gc-amf
```

Note:

Dangling images may be created during the build process. It is advised to remove them from time to time to free up disk space.

```bash
docker rmi $(docker images -f "dangling=true" -q)
```

### Run free5GC

You can create free5GC containers based on local images or docker hub images:

```bash
# default one-UPF stack using the userspace forwarder
docker compose up # add -d to run in background mode

# one-UPF stack using the gtp5g forwarder
UPF_CONFIG_PATH=./config/upfcfg.yaml docker compose up

# use local userspace images
docker compose -f docker-compose-build.yaml up

# use local images with the gtp5g forwarder
UPF_CONFIG_PATH=./config/upfcfg.yaml docker compose -f docker-compose-build.yaml up
```

The forwarder mode is selected via `UPF_CONFIG_PATH` and defaults to userspace:

```bash
# userspace (default)
export UPF_CONFIG_PATH=./config/upfcfg-userspace.yaml

# gtp5g
export UPF_CONFIG_PATH=./config/upfcfg.yaml
```

Destroy the established container resource after testing:

```bash
# Remove established containers (default userspace stack)
docker compose rm

# Remove established containers (gtp5g stack)
UPF_CONFIG_PATH=./config/upfcfg.yaml docker compose rm

# Remove established containers (local userspace images)
docker compose -f docker-compose-build.yaml rm

# Remove established containers (local gtp5g images)
UPF_CONFIG_PATH=./config/upfcfg.yaml docker compose -f docker-compose-build.yaml rm
```

## Troubleshooting

Please refer to the [Troubleshooting](./TROUBLESHOOTING.md) for more troubleshooting information.

## Test Notes

- [UE to UPF N3 Ping](./UE_UPF_N3_PING.md)
- [UPF Performance Tests](./UPF_PERFORMANCE_TESTS.md)
- [Two-UE Userspace UPF Deployment Guide](./TWO_UE_USERSPACE_UPF_DEPLOYMENT.md)

## Integration with gNB/UE

### UERANSIM Go (Internalized)

The project now includes an internalized Go implementation of UERANSIM located at `./base/free5gc/ueransim-go`. The gNB and UE are orchestrated as separate services in `docker-compose-build.yaml`.

#### Option 1: Using the orchestrated services

The `docker-compose-build.yaml` file defines two services: `ueransim` (acting as gNB) and `ue`.

```bash
# Build and start the services
docker compose -f docker-compose-build.yaml build ueransim ue
docker compose -f docker-compose-build.yaml up -d ueransim ue
```

#### Option 2: Running commands manually

If you need to interact with the UE (e.g., for ping or iperf), use the `ue` container:

```bash
# Check if the TUN interface is up
docker exec ue ip addr show uesimtun0

# Ping through the tunnel
docker exec ue ping -I uesimtun0 8.8.8.8
```

To create a new subscriber:
1. Create a subscriber through the WebUI. Follow the steps [here](https://free5gc.org/guide/Webconsole/Create-Subscriber-via-webconsole/#4-open-webconsole)
1. Copy the `UE ID` field
1. Change the value of `supi` in `config/uecfg.yaml` to the UE ID that you just copied
1. Restart the UE service: `docker compose -f docker-compose-build.yaml restart ue`


### srsRAN Notes

You can check this [issue](https://github.com/acore2026/free5gc-compose/issues/94) for some sample configuration files of srsRAN + free5GC

## Integration of WebUI with Nginx reverse proxy

Here you can find helpful guidelines on the integration of Nginx reverse proxy to set it in front of the WebUI: https://github.com/acore2026/free5gc-compose/issues/55#issuecomment-1146648600

## ULCL Configuration

To start the core with a I-UPF and PSA-UPF ULCL configuration, use

```bash
docker compose -f docker-compose-ulcl.yaml up
```

> Note: This configuration have been tested using release [free5gc-compose v4.0.0](https://github.com/acore2026/free5gc-compose/tree/v4.0.0)

Check out the used configuration files at `config/ULCL`.

## Generic Multi-UPF Configuration

To start the core with three generic UPFs that can each be used as an ingress, intermediate, or anchoring UPF depending on the SMF routing graph, use

```bash
docker compose -f docker-compose-multi-upf.yaml up
```

This variant keeps the UPFs generic (`upf1`, `upf2`, `upf3`) and moves the role selection into `config/multi-upf/smfcfg.yaml` and `config/multi-upf/uerouting.yaml`.

## Prometheous & Grafana

To start the core with Prometheous and Grafana, we need external compose service file to start with our core compose:

```bash
docker compose -f docker-compose.yaml -f docker-compose-prometheus.yaml up
```

Please make sure the metrics secions are enabled in NFs' config, it is disabled in default:

```yaml
  # Metrics configuration
  # If using the same bindingIPv4 as the sbi server, make sure that the ports are different
  metrics:
=>  enable: true # (Optional, default false)
    scheme: http # (Required) the protocol for metrics (http or https, default https)
    bindingIPv4: amf.free5gc.org # (Required) IP used to bind the metrics endpoint (default 0.0.0.0)
    port: 9091 # (Optional, default 9091) port used to bind the service
    tls: # (Optional) the local path of TLS key (Could be the same as the sbi ones)
      pem: cert/amf.pem # AMF TLS Certificate
      key: cert/amf.key # AMF TLS Private key
    namespace: free5gc # (Optional, default free5gc)
```

## Reference

- https://github.com/open5gs/nextepc/tree/master/docker
- https://github.com/abousselmi/docker-free5gc
