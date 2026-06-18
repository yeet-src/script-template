#!/bin/sh
# Producer step: pull the official static esbuild binary from the
# @esbuild/<platform> npm package into v/<arch>/esbuild so CI can re-host it on
# our toolchain release. The consumer-facing integrity check is the published
# binary's checksum (versions.env, verified by build/fetch-toolchain.sh), so
# this upstream fetch — run in CI over TLS — isn't pinned. Keep ESBUILD_VERSION
# in sync with template/package.json.
#
#   build/fetch-esbuild.sh [amd64|arm64]   (default: both)

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
V="$(dirname "$HERE")"
. "$HERE/versions.env"

fetch() {
	plat="$1"
	case "$plat" in
		amd64) arch=x86_64;  npmpkg=linux-x64   ;;
		arm64) arch=aarch64; npmpkg=linux-arm64 ;;
		*) echo "error: unknown arch '$plat'" >&2; exit 1 ;;
	esac
	url="https://registry.npmjs.org/@esbuild/${npmpkg}/-/${npmpkg}-${ESBUILD_VERSION}.tgz"
	tmp="$(mktemp -d)"
	echo ">> fetching esbuild ${ESBUILD_VERSION} for ${plat}"
	curl -fSL -o "$tmp/eb.tgz" "$url"
	mkdir -p "$V/$arch"
	tar xzf "$tmp/eb.tgz" -C "$tmp"
	cp "$tmp/package/bin/esbuild" "$V/$arch/esbuild"
	chmod +x "$V/$arch/esbuild"
	rm -rf "$tmp"
	echo ">> done: $V/$arch/esbuild"
}

if [ "$#" -eq 0 ]; then
	fetch amd64
	fetch arm64
else
	fetch "$1"
fi
