#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
if [[ ${1:-} == --help ]]; then
    echo 'Usage: bash build-images.sh [--check]'
    echo 'Sync pinned sources and build images. No services are restarted.'
    echo '--check: sync sources and check local base images only.'
    exit 0
fi
[[ $# == 0 || ( $# == 1 && $1 == --check ) ]] || { echo 'Invalid arguments' >&2; exit 1; }
for cmd in git docker tar mktemp; do command -v "$cmd" >/dev/null; done
paths=(nf_amf/amf nf_smf/smf nf_upf/upf)
nfs=(amf smf upf)
bases=("${AMF_BASE_IMAGE:-free5gc/amf:buildv18}"
       "${SMF_BASE_IMAGE:-free5gc/smf:fix-setup-9a4d8ba}"
       "${UPF_BASE_IMAGE:-free5gc/upf:v4.2.1.ac2}")
revisions=()
base_ids=()

# Refuse tracked edits; clean checkouts may advance to the deployment pin.
for path in "${paths[@]}"; do
    if [[ -e $path/.git ]]; then
        git -C "$path" diff --quiet && git -C "$path" diff --cached --quiet || {
            echo "Tracked changes in $path; commit or stash first." >&2; exit 1;
        }
    fi
    git diff --cached --quiet HEAD -- "$path" || {
        echo "Staged gitlink change in $path; commit first." >&2; exit 1;
    }
done
git submodule sync -- "${paths[@]}"
git submodule update --init -- "${paths[@]}"
for i in "${!paths[@]}"; do
    revision=$(git rev-parse "HEAD:${paths[$i]}")
    [[ $(git -C "${paths[$i]}" rev-parse HEAD) == "$revision" ]] || exit 1
    revisions+=("$revision")
    base_ids+=("$(docker image inspect --format '{{.Id}}' "${bases[$i]}")")
    [[ $(docker image inspect --format '{{.Os}}/{{.Architecture}}' "${bases[$i]}") == linux/amd64 ]] || {
        echo "Base image must be linux/amd64: ${bases[$i]}" >&2; exit 1;
    }
    printf '%s source=%s base=%s\n' "${nfs[$i]}" "$revision" "${base_ids[$i]}"
done
[[ ${1:-} != --check ]] || exit 0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf 'version: "3.8"\nservices:\n' > "$tmp/compose.yaml"
for i in "${!paths[@]}"; do
    nf=${nfs[$i]}
    revision=${revisions[$i]}
    context="$tmp/$nf"
    mkdir -p "$context/$nf"
    git -C "${paths[$i]}" archive "$revision" | tar -x -C "$context/$nf"
    cp Dockerfile.source "$context/Dockerfile"
    tag="free5gc/$nf:rebuilt-${revision:0:12}"
    docker build --pull=false --platform linux/amd64 \
        --build-arg "GO_IMAGE=${GO_IMAGE:-golang:1.25.5-trixie}" \
        --build-arg "BASE_IMAGE=${base_ids[$i]}" \
        --build-arg "BASE_REVISION=${base_ids[$i]}" \
        --build-arg "NF=$nf" --build-arg "SOURCE_REVISION=$revision" \
        --build-arg "GOPROXY=${GOPROXY:-https://proxy.golang.org,direct}" \
        -t "$tag" "$context"
    printf '  free5gc-%s:\n    image: %s\n' "$nf" "$tag" >> "$tmp/compose.yaml"
done
mv "$tmp/compose.yaml" docker-compose.built.yaml
echo 'Build complete. No running containers were changed.'
echo 'Activate: COMPOSE_FILE=docker-compose.yaml:docker-compose.built.yaml bash restart-all.sh'
