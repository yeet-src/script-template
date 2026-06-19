#!/bin/sh
# Producer step: extract the official static lvh (cilium's little-vm-helper)
# binary from the quay.io/lvh-images/lvh OCI image into v/<arch>/lvh so CI can
# re-host it on our toolchain release.
#
# lvh is NOT a build tool — it's the VM orchestrator for the optional
# kernel-matrix test runner, paired with the vendored qemu. But it's a single
# fully-static Go binary, so we re-host it like bpftool/esbuild rather than
# build it. The consumer-facing integrity check is the published binary's
# checksum (versions.env, verified by the matrix runner), so this upstream
# extract — run in CI — isn't pinned. lvh ships ONLY as an OCI image, so this
# needs docker (CI runners have it); pass an arch to do just one.
#
#   build/fetch-lvh.sh [amd64|arm64]   (default: both)

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
V="$(dirname "$HERE")"
. "$HERE/versions.env"

fetch() {
	plat="$1"
	case "$plat" in
		amd64) arch=x86_64  ;;
		arm64) arch=aarch64 ;;
		*) echo "error: unknown arch '$plat'" >&2; exit 1 ;;
	esac
	img="quay.io/lvh-images/lvh:${LVH_VERSION}"
	echo ">> extracting lvh ${LVH_VERSION} for ${plat}"
	# Create (not run) a container of the target-arch image and copy the
	# binary out — no execution, so cross-arch extraction works on any host.
	docker pull --platform "linux/${plat}" -q "$img" >/dev/null
	cid="$(docker create --platform "linux/${plat}" "$img")"
	mkdir -p "$V/$arch"
	docker cp "$cid:/usr/bin/lvh" "$V/$arch/lvh"
	docker rm "$cid" >/dev/null
	chmod +x "$V/$arch/lvh"
	echo ">> done: $V/$arch/lvh"
}

if [ "$#" -eq 0 ]; then
	fetch amd64
	fetch arm64
else
	fetch "$1"
fi
