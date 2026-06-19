#!/bin/sh
# Build the static qemu-system for one arch and drop a minimal tree in
# v/<arch>/qemu/ — the binary under bin/ and only the firmware blobs that arch's
# machine actually loads under share/qemu/ (see Dockerfile.qemu).
#
#   build/build-qemu.sh <amd64|arm64>
#
# This is NOT part of the build toolchain — qemu is a VM host for the optional
# kernel-matrix test runner (it needs host KVM + root at runtime), fetched on
# demand rather than resolved by `make`. Build it per-arch on a NATIVE runner:
# compiling qemu under emulation (e.g. x86_64 on an arm64 host) is brutal, same
# as clang — see build-clang.sh / the native-runner matrix in vendor.yml.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
V="$(dirname "$HERE")"
. "$HERE/versions.env"

PLAT="${1:?usage: build-qemu.sh <amd64|arm64>}"
case "$PLAT" in
	amd64)  ARCH=x86_64;  TARGET=x86_64-softmmu  ;;
	arm64)  ARCH=aarch64; TARGET=aarch64-softmmu ;;
	*) echo "error: arch must be amd64 or arm64, got '$PLAT'" >&2; exit 1 ;;
esac

OUT="$V/$ARCH/qemu"
rm -rf "$OUT"
mkdir -p "$OUT"

echo ">> building static qemu ${QEMU_VERSION} (${TARGET}) for linux/${PLAT} -> $OUT"
docker buildx build \
	--platform "linux/${PLAT}" \
	-f "$HERE/Dockerfile.qemu" \
	--build-arg "QEMU_VERSION=${QEMU_VERSION}" \
	--build-arg "QEMU_TARGET=${TARGET}" \
	--build-arg "LIBSLIRP_VERSION=${LIBSLIRP_VERSION}" \
	--build-arg "ALPINE_TAG=${ALPINE_TAG}" \
	--target export \
	--output "type=local,dest=${OUT}" \
	"$HERE"

chmod +x "$OUT/bin/qemu-system-${ARCH}"
echo ">> done:"
ls -la "$OUT/bin"
du -sh "$OUT/bin" "$OUT/share/qemu"
