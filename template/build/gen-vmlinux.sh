#!/bin/sh
# Generate vmlinux.h from the running kernel's BTF — the CO-RE header
# every BPF program in this project includes.
#
#   build/gen-vmlinux.sh <bpftool> <output-path>
#
# <bpftool> may be a multi-word command (`yeet toolchain exec bpftool`), so it
# is word-split on use, deliberately.

set -eu

BPFTOOL="${1:-bpftool}"
OUT="${2:-src/bpf/include/vmlinux.h}"

if [ ! -r /sys/kernel/btf/vmlinux ]; then
	echo "error: /sys/kernel/btf/vmlinux is not readable — kernel BTF (CONFIG_DEBUG_INFO_BTF) is required" >&2
	exit 1
fi

mkdir -p "$(dirname "$OUT")"
err="$(mktemp)"
trap 'rm -f "$err"' EXIT
# Mark the generated header as a system header so clang keeps -Wall quiet
# about it. The dump is not warning-clean: the kernel builds with tagged
# anonymous members (`struct foo;` as an unnamed struct/union member), which
# bpftool emits verbatim and clang >= 22 flags with -Wmissing-declarations.
# Nothing in it is ours to fix, and the pragma only affects diagnostics —
# CO-RE relocations and preserve_access_index are untouched.
# On failure, drop the partial header so make doesn't take it for a good one.
{
	echo "#pragma clang system_header"
	# shellcheck disable=SC2086
	$BPFTOOL btf dump file /sys/kernel/btf/vmlinux format c
} >"$OUT" 2>"$err" || { cat "$err" >&2; rm -f "$OUT"; exit 1; }
# bpftool notes that the kernel BTF "will be loaded as base" — expected here,
# so keep it out of the build output; anything else it said goes through.
grep -v 'will be loaded as base' "$err" >&2 || true
