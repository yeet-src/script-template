#!/bin/sh
# Producer step: pull the official static veristat binary from libbpf/veristat
# into v/<arch>/veristat so CI can re-host it on our toolchain release. The
# consumer-facing integrity check is the published binary's checksum, recorded
# in versions.env by CI and verified by build/fetch-toolchain.sh — so this
# upstream fetch (run in CI from the official release over TLS) isn't pinned.
#
#   build/fetch-veristat.sh [amd64|arm64]   (default: both)

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
	url="https://github.com/libbpf/veristat/releases/download/v${VERISTAT_VERSION}/veristat-v${VERISTAT_VERSION}-${plat}.tar.gz"
	tmp="$(mktemp -d)"
	echo ">> fetching veristat ${VERISTAT_VERSION} for ${plat}"
	curl -fSL -o "$tmp/vs.tar.gz" "$url"
	mkdir -p "$V/$arch"
	tar xzf "$tmp/vs.tar.gz" -C "$tmp"
	cp "$tmp/veristat" "$V/$arch/veristat"
	chmod +x "$V/$arch/veristat"
	rm -rf "$tmp"
	echo ">> done: $V/$arch/veristat"
}

if [ "$#" -eq 0 ]; then
	fetch amd64
	fetch arm64
else
	fetch "$1"
fi
