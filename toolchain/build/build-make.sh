#!/bin/sh
# Build the static GNU make for one arch and drop it in v/<arch>/make.
#
#   build/build-make.sh <amd64|arm64>
#
# Fast even under emulation (make builds in seconds), so both arches can be
# built on a single host.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
V="$(dirname "$HERE")"
. "$HERE/versions.env"

PLAT="${1:?usage: build-make.sh <amd64|arm64>}"
case "$PLAT" in
	amd64)  ARCH=x86_64 ;;
	arm64)  ARCH=aarch64 ;;
	*) echo "error: arch must be amd64 or arm64, got '$PLAT'" >&2; exit 1 ;;
esac

OUT="$V/$ARCH"
mkdir -p "$OUT"

echo ">> building static make ${MAKE_VERSION} for linux/${PLAT} -> $OUT/make"
docker buildx build \
	--platform "linux/${PLAT}" \
	-f "$HERE/Dockerfile.make" \
	--build-arg "MAKE_VERSION=${MAKE_VERSION}" \
	--build-arg "ALPINE_TAG=${ALPINE_TAG}" \
	--target export \
	--output "type=local,dest=${OUT}" \
	"$HERE"

chmod +x "$OUT/make"
echo ">> done: $(ls -la "$OUT/make")"
