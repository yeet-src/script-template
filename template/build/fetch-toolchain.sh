#!/bin/sh
# Populate a shared toolchain cache directory, downloading each tool only if
# it is missing. Every artifact comes from our single version-addressed
# "toolchain" release and is checksum-verified against the pins in the lock.
#
#   build/fetch-toolchain.sh <dest-dir> <uname-arch> <lock> [tool...]
#
# With no trailing tool names, all tools are fetched (the build's `toolchain`
# target). Pass names (e.g. `git`) to fetch only those — `postgen.sh` uses
# this to grab just git at generation time without pulling the whole toolchain.
#
# Idempotent: a present binary is left untouched, so the first build downloads
# the toolchain and every later build (or other project on the same version)
# is a cache hit.

set -eu

DIR="${1:?usage: fetch-toolchain.sh <dest-dir> <arch> <lock> [tool...]}"
ARCH="${2:?missing arch}"
LOCK="${3:?missing lock}"
shift 3
FILTER="$*"   # empty = all tools

# shellcheck disable=SC1090
. "$LOCK"

case "$ARCH" in
	x86_64 | aarch64) ;;
	*) echo "error: unsupported arch '$ARCH'" >&2; exit 1 ;;
esac

mkdir -p "$DIR"

want() { [ -z "$FILTER" ] && return 0; case " $FILTER " in *" $1 "*) return 0 ;; esac; return 1; }

sha() {
	if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
	elif command -v shasum    >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
	else echo "error: no sha256 tool (sha256sum/shasum) found" >&2; return 1; fi
}

verify() { # file want-sha label
	[ -n "$2" ] || { echo "warning: no pinned checksum for $3 — skipping verify" >&2; return 0; }
	got="$(sha "$1")"
	[ "$got" = "$2" ] || { echo "error: $3 checksum mismatch: got $got want $2" >&2; return 1; }
}

get_sha() { eval "printf '%s' \"\${${1}_SHA256_${ARCH}:-}\""; }  # get_sha CLANG

# fetch_bin <tool-name> <release-asset-name>
# Atomic: download beside the target, verify, then rename, so a concurrent
# build never sees a half-written binary.
fetch_bin() {
	name="$1"; asset="$2"
	want "$name" || return 0
	[ -x "$DIR/$name" ] && return 0
	echo ">> fetch ${name} (${ARCH})"
	tmp="$DIR/.${name}.$$"
	curl -fSL --retry 3 -o "$tmp" "${TOOLCHAIN_BASE_URL}/${asset}"
	verify "$tmp" "$(get_sha "$(echo "$name" | tr a-z A-Z)")" "$name" || { rm -f "$tmp"; exit 1; }
	chmod +x "$tmp"
	mv -f "$tmp" "$DIR/$name"
}

fetch_bin make    "make-${ARCH}-${MAKE_VERSION}"
fetch_bin clang   "clang-${ARCH}-llvm${LLVM_VERSION}"
fetch_bin bpftool "bpftool-${ARCH}-v${BPFTOOL_VERSION}"
fetch_bin esbuild "esbuild-${ARCH}-${ESBUILD_VERSION}"
fetch_bin git     "git-${ARCH}-v${GIT_VERSION}"

# libbpf program headers: arch-independent, one copy per version key, beside
# the per-arch tool dirs ($key/include/bpf/*.h).
INC="$(dirname "$DIR")/include"
if want headers && [ ! -e "$INC/bpf/bpf_helpers.h" ]; then
	echo ">> fetch libbpf headers (bpftool ${BPFTOOL_VERSION})"
	td="$(mktemp -d)"
	curl -fSL --retry 3 -o "$td/h.tgz" \
		"${TOOLCHAIN_BASE_URL}/libbpf-headers-v${BPFTOOL_VERSION}.tar.gz"
	verify "$td/h.tgz" "${LIBBPF_HEADERS_SHA256:-}" "libbpf-headers" || { rm -rf "$td"; exit 1; }
	mkdir -p "$INC"
	tar xzf "$td/h.tgz" -C "$INC"   # tarball holds a top-level bpf/ dir
	rm -rf "$td"
fi

echo ">> toolchain ready: $DIR${FILTER:+ ($FILTER)}"
