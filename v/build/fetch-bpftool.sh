#!/bin/sh
# Fetch the official static bpftool release and drop it in v/<arch>/bpftool.
#
#   build/fetch-bpftool.sh [amd64|arm64]   (default: both)
#
# These are prebuilt fully-static binaries from libbpf/bpftool — no build
# needed. Checksums are pinned in versions.env.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
V="$(dirname "$HERE")"
. "$HERE/versions.env"

sha() {
	if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
	elif command -v shasum    >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
	else echo "error: no sha256 tool (sha256sum/shasum) found" >&2; return 1; fi
}

fetch() {
	plat="$1"
	case "$plat" in
		amd64) arch=x86_64;  sum="$BPFTOOL_SHA256_amd64" ;;
		arm64) arch=aarch64; sum="$BPFTOOL_SHA256_arm64" ;;
		*) echo "error: unknown arch '$plat'" >&2; exit 1 ;;
	esac
	url="https://github.com/libbpf/bpftool/releases/download/v${BPFTOOL_VERSION}/bpftool-v${BPFTOOL_VERSION}-${plat}.tar.gz"
	tmp="$(mktemp -d)"
	echo ">> fetching bpftool ${BPFTOOL_VERSION} for ${plat}"
	curl -fSL -o "$tmp/bt.tar.gz" "$url"
	got="$(sha "$tmp/bt.tar.gz")"
	if [ -n "$sum" ] && [ "$got" != "$sum" ]; then
		echo "error: checksum mismatch for ${plat}: got $got want $sum" >&2
		rm -rf "$tmp"; exit 1
	fi
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
