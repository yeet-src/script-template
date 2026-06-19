#!/bin/sh
# Extract the libbpf program-side headers (<bpf/bpf_helpers.h>, …) into
# v/include/bpf/. These are SDK-level, version-tied to bpftool/libbpf — not
# application source — and shared across arches. Pulled from the bpftool
# sources release so they always match the vendored bpftool's libbpf.
#
#   build/fetch-libbpf-headers.sh

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
V="$(dirname "$HERE")"
. "$HERE/versions.env"

# The program-side subset a BPF unit includes; the rest of libbpf is the
# userspace loader API, which we don't compile against here.
HDRS="bpf_helpers.h bpf_helper_defs.h bpf_endian.h bpf_tracing.h bpf_core_read.h usdt.bpf.h"

url="https://github.com/libbpf/bpftool/releases/download/v${BPFTOOL_VERSION}/bpftool-libbpf-v${BPFTOOL_VERSION}-sources.tar.gz"
tmp="$(mktemp -d)"
echo ">> fetching libbpf headers (bpftool ${BPFTOOL_VERSION} sources)"
curl -fSL --retry 3 -o "$tmp/src.tar.gz" "$url"
tar xzf "$tmp/src.tar.gz" -C "$tmp"
srcdir="$(find "$tmp" -type d -path '*libbpf/src' | head -1)"
[ -n "$srcdir" ] || { echo "error: libbpf/src not found in sources" >&2; exit 1; }

mkdir -p "$V/include/bpf"
for h in $HDRS; do
	cp "$srcdir/$h" "$V/include/bpf/$h"
done
rm -rf "$tmp"
echo ">> done: $V/include/bpf ($(ls "$V/include/bpf" | wc -l | tr -d ' ') headers)"
