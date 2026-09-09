# Build replacement NF images

On a second machine with the same layout:

```sh
cd /home/core/free5gc-compose-new
git fetch origin
git switch vivo-ran-01
git pull --ff-only origin vivo-ran-01
bash build-images.sh --check
bash build-images.sh
```

Save local changes first. Plain Git pull does not initialize submodules. The
script synchronizes only AMF/SMF/UPF to deployment HEAD's pinned commits, avoiding
unrelated legacy gitlinks with missing mappings. GitHub SSH access is required.
Tracked edits and staged gitlink changes are rejected. Clean source checkouts
are moved to the pinned commit. Untracked binaries are excluded by git archive.

## Prerequisites

Docker, Git, Bash, tar and registry/Go module access are required. These local
runtime images must already exist:

- AMF: `free5gc/amf:buildv18`
- SMF: `free5gc/smf:fix-setup-9a4d8ba`
- UPF: `free5gc/upf:v4.2.1.ac2`

Override using AMF_BASE_IMAGE, SMF_BASE_IMAGE, UPF_BASE_IMAGE for equivalent
local images. Compare printed image IDs between machines, not just tags.
Git does not distribute these images. Machines without them must obtain them
from a registry or separately rebuild the runtime base first.

The default compiler image is golang:1.25.5-trixie (override GO_IMAGE).
All builds use linux/amd64 and GOAMD64=v1. AMF/SMF use CGO_ENABLED=0 and
`-ldflags="-s -w"`; UPF uses CGO_ENABLED=1 and ./cmd/main.go without stripping.
These match settings recovered from current binaries. The historical UPF C
toolchain was not recorded; runtime compatibility still requires verification.
Use `GOPROXY=https://goproxy.cn,direct bash build-images.sh` for a Go proxy mirror.
Go checksum verification remains enabled.

## Activation

Only the NF binary and provenance labels are replaced; the base runtime is
retained. Tags are free5gc/<nf>:rebuilt-<12-char-sha>. Rebuilding reuses this new
tag, never the original base tags. All builds must succeed before the ignored
docker-compose.built.yaml is written. Running containers are not changed.

Review the generated override, then during a maintenance window:

```sh
COMPOSE_FILE=docker-compose.yaml:docker-compose.built.yaml bash restart-all.sh
```

Supply this override on subsequent restarts, including with the outer
/home/core/restart-all.sh; otherwise original tags are selected. Activation
restarts the cluster and auxiliary services; UEs must reconnect. Host networking,
offload services, certificates and auxiliary projects remain prerequisites.

Verify UE registration and traffic before accepting rebuilt images. The current
AMF binary reports an older commit with dirty source; the published source pin
is not proof of byte-for-byte equivalence to it. Exact image reproduction needs
all compiler/base/dependency inputs pinned, or distribution by image digest.
