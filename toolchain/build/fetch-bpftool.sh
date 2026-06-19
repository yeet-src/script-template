#!/bin/sh
# Producer step: pull the official static bpftool binary from libbpf/bpftool
# into v/<arch>/bpftool so CI can re-host it on our toolchain release. The
# consumer-facing integrity check is the published binary's checksum, recorded
# in versions.env by CI and verified by build/fetch-toolchain.sh — so this
# upstream fetch (run in CI from the official release over TLS) isn't pinned.
#
#   build/fetch-bpftool.sh [amd64|arm64]   (default: both)

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
	url="https://github.com/libbpf/bpftool/releases/download/v${BPFTOOL_VERSION}/bpftool-v${BPFTOOL_VERSION}-${plat}.tar.gz"
	tmp="$(mktemp -d)"
	echo ">> fetching bpftool ${BPFTOOL_VERSION} for ${plat}"
	curl -fSL -o "$tmp/bt.tar.gz" "$url"
	mkdir -p "$V/$arch"
	tar xzf "$tmp/bt.tar.gz" -C "$tmp"
	cp "$tmp/bpftool" "$V/$arch/bpftool"
	chmod +x "$V/$arch/bpftool"
	rm -rf "$tmp"
	echo ">> done: $V/$arch/bpftool"
}

if [ "$#" -eq 0 ]; then
	fetch amd64
	fetch arm64
else
	fetch "$1"
fi
