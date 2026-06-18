#!/bin/sh
# Fetch the official static esbuild binary and drop it in v/<arch>/esbuild.
#
#   build/fetch-esbuild.sh [amd64|arm64]   (default: both)
#
# esbuild ships a prebuilt, statically-linked Go binary per platform in the
# @esbuild/<platform> npm packages — no Node or `npm install` needed to run
# it. Pin and checksum live in versions.env; keep ESBUILD_VERSION in sync
# with template/package.json.

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
		amd64) arch=x86_64;  npmpkg=linux-x64;   sum="$ESBUILD_SHA256_amd64" ;;
		arm64) arch=aarch64; npmpkg=linux-arm64; sum="$ESBUILD_SHA256_arm64" ;;
		*) echo "error: unknown arch '$plat'" >&2; exit 1 ;;
	esac
	url="https://registry.npmjs.org/@esbuild/${npmpkg}/-/${npmpkg}-${ESBUILD_VERSION}.tgz"
	tmp="$(mktemp -d)"
	echo ">> fetching esbuild ${ESBUILD_VERSION} for ${plat}"
	curl -fSL -o "$tmp/eb.tgz" "$url"
	got="$(sha "$tmp/eb.tgz")"
	if [ -n "$sum" ] && [ "$got" != "$sum" ]; then
		echo "error: checksum mismatch for ${plat}: got $got want $sum" >&2
		rm -rf "$tmp"; exit 1
	fi
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
