#!/bin/sh
# Build the lean static git for one arch and drop it in v/<arch>/git.
#
#   build/build-git.sh <amd64|arm64>
#
# Quick to build (network features off), so both arches build fine on one host.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
V="$(dirname "$HERE")"
. "$HERE/versions.env"

PLAT="${1:?usage: build-git.sh <amd64|arm64>}"
case "$PLAT" in
	amd64)  ARCH=x86_64 ;;
	arm64)  ARCH=aarch64 ;;
	*) echo "error: arch must be amd64 or arm64, got '$PLAT'" >&2; exit 1 ;;
esac

OUT="$V/$ARCH"
mkdir -p "$OUT"

echo ">> building static git ${GIT_VERSION} for linux/${PLAT} -> $OUT/git"
docker buildx build \
	--platform "linux/${PLAT}" \
	-f "$HERE/Dockerfile.git" \
	--build-arg "GIT_VERSION=${GIT_VERSION}" \
	--build-arg "ALPINE_TAG=${ALPINE_TAG}" \
	--target export \
	--output "type=local,dest=${OUT}" \
	"$HERE"

chmod +x "$OUT/git"
echo ">> done: $(ls -la "$OUT/git")"
