#!/bin/sh
# Producer step: pull the official static gh (GitHub CLI) binary from cli/cli
# into v/<arch>/gh so CI can re-host it on our toolchain release. gh is a single
# fully-static Go binary, so we re-host it like esbuild/veristat rather than
# build it. The consumer-facing integrity check is the published binary's
# checksum (versions.env, verified by build/fetch-toolchain.sh), so this
# upstream fetch — run in CI from the official release over TLS — isn't pinned.
#
#   build/fetch-gh.sh [amd64|arm64]   (default: both)

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
	url="https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${plat}.tar.gz"
	tmp="$(mktemp -d)"
	echo ">> fetching gh ${GH_VERSION} for ${plat}"
	curl -fSL -o "$tmp/gh.tar.gz" "$url"
	mkdir -p "$V/$arch"
	tar xzf "$tmp/gh.tar.gz" -C "$tmp"
	# Tarball extracts to gh_<ver>_linux_<plat>/bin/gh; glob the version dir.
	cp "$tmp"/gh_*/bin/gh "$V/$arch/gh"
	chmod +x "$V/$arch/gh"
	rm -rf "$tmp"
	echo ">> done: $V/$arch/gh"
}

if [ "$#" -eq 0 ]; then
	fetch amd64
	fetch arm64
else
	fetch "$1"
fi
