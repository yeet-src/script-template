#!/bin/sh
# Populate a shared toolchain cache directory, downloading each tool only if
# it is missing. Called by the `toolchain` make target.
#
#   build/fetch-toolchain.sh <dest-dir> <uname-arch> <toolchain.lock>
#
# Idempotent: an already-present binary is left untouched, so the first build
# on a machine downloads the toolchain and every later build (and every other
# project pinned to the same version) is a cache hit. Downloads are
# checksum-verified against the pins in <toolchain.lock>.

set -eu

DIR="${1:?usage: fetch-toolchain.sh <dest-dir> <arch> <lock>}"
ARCH="${2:?missing arch}"
LOCK="${3:?missing lock}"

# shellcheck disable=SC1090
. "$LOCK"

case "$ARCH" in
	x86_64)  PLAT=amd64; ESB=linux-x64   ;;
	aarch64) PLAT=arm64; ESB=linux-arm64 ;;
	*) echo "error: unsupported arch '$ARCH'" >&2; exit 1 ;;
esac

mkdir -p "$DIR"

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

# Install atomically: download beside the target, verify, then rename, so a
# concurrent build never sees a half-written binary.
place() { # tmpfile destname
	chmod +x "$1"
	mv -f "$1" "$DIR/$2"
}

# --- clang: our version-addressed release asset --------------------------
if [ ! -x "$DIR/clang" ]; then
	eval "want=\${CLANG_SHA256_${ARCH}:-}"
	echo ">> fetch clang llvm${LLVM_VERSION} (${ARCH})"
	tmp="$DIR/.clang.$$"
	curl -fSL --retry 3 -o "$tmp" "${TOOLCHAIN_BASE_URL}/clang-${ARCH}-llvm${LLVM_VERSION}"
	verify "$tmp" "$want" "clang" || { rm -f "$tmp"; exit 1; }
	place "$tmp" clang
fi

# --- bpftool: upstream static release ------------------------------------
if [ ! -x "$DIR/bpftool" ]; then
	eval "want=\${BPFTOOL_SHA256_${PLAT}:-}"
	echo ">> fetch bpftool ${BPFTOOL_VERSION} (${PLAT})"
	td="$(mktemp -d)"
	curl -fSL --retry 3 -o "$td/b.tgz" \
		"https://github.com/libbpf/bpftool/releases/download/v${BPFTOOL_VERSION}/bpftool-v${BPFTOOL_VERSION}-${PLAT}.tar.gz"
	verify "$td/b.tgz" "$want" "bpftool" || { rm -rf "$td"; exit 1; }
	tar xzf "$td/b.tgz" -C "$td"
	place "$td/bpftool" bpftool
	rm -rf "$td"
fi

# --- libbpf program headers: arch-independent, one copy per version key ---
# Live beside the per-arch tool dirs ($key/include/bpf/*.h) so every arch
# shares them. Fetched from our version-addressed release asset.
INC="$(dirname "$DIR")/include"
if [ ! -e "$INC/bpf/bpf_helpers.h" ]; then
	want="${LIBBPF_HEADERS_SHA256:-}"
	echo ">> fetch libbpf headers (bpftool ${BPFTOOL_VERSION})"
	td="$(mktemp -d)"
	curl -fSL --retry 3 -o "$td/h.tgz" \
		"${TOOLCHAIN_BASE_URL}/libbpf-headers-v${BPFTOOL_VERSION}.tar.gz"
	verify "$td/h.tgz" "$want" "libbpf-headers" || { rm -rf "$td"; exit 1; }
	mkdir -p "$INC"
	tar xzf "$td/h.tgz" -C "$INC"   # tarball holds a top-level bpf/ dir
	rm -rf "$td"
fi

# --- esbuild: upstream npm platform package ------------------------------
if [ ! -x "$DIR/esbuild" ]; then
	eval "want=\${ESBUILD_SHA256_${PLAT}:-}"
	echo ">> fetch esbuild ${ESBUILD_VERSION} (${PLAT})"
	td="$(mktemp -d)"
	curl -fSL --retry 3 -o "$td/e.tgz" \
		"https://registry.npmjs.org/@esbuild/${ESB}/-/${ESB}-${ESBUILD_VERSION}.tgz"
	verify "$td/e.tgz" "$want" "esbuild" || { rm -rf "$td"; exit 1; }
	tar xzf "$td/e.tgz" -C "$td"
	place "$td/package/bin/esbuild" esbuild
	rm -rf "$td"
fi

echo ">> toolchain ready: $DIR"
