#!/bin/sh
# Build the fully-static clang for one arch and drop it in v/<arch>/clang.
#
#   build/build-clang.sh <amd64|arm64>
#
# Runs the Dockerfile.clang build for the given platform and extracts the
# binary. On an arm64 host, `amd64` runs under QEMU emulation and a full LLVM
# build there takes many hours — prefer a native runner (see vendor.yml).

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
V="$(dirname "$HERE")"
. "$HERE/versions.env"

PLAT="${1:?usage: build-clang.sh <amd64|arm64>}"
case "$PLAT" in
	amd64)  ARCH=x86_64 ;;
	arm64)  ARCH=aarch64 ;;
	*) echo "error: arch must be amd64 or arm64, got '$PLAT'" >&2; exit 1 ;;
esac

OUT="$V/$ARCH"
mkdir -p "$OUT"

# Compile parallelism is memory-bound (~1-2GB per heavy TU). Default low so
# the build fits a typical 8GB Docker VM without OOM; override COMPILE_JOBS
# upward on a high-RAM machine.
COMPILE_JOBS="${COMPILE_JOBS:-3}"

echo ">> building static clang ${LLVM_VERSION} for linux/${PLAT} (compile jobs: ${COMPILE_JOBS}) -> $OUT/clang"
docker buildx build \
	--platform "linux/${PLAT}" \
	-f "$HERE/Dockerfile.clang" \
	--build-arg "LLVM_VERSION=${LLVM_VERSION}" \
	--build-arg "ALPINE_TAG=${ALPINE_TAG}" \
	--build-arg "COMPILE_JOBS=${COMPILE_JOBS}" \
	--target export \
	--output "type=local,dest=${OUT}" \
	"$HERE"

chmod +x "$OUT/clang"
echo ">> done: $(ls -la "$OUT/clang")"
