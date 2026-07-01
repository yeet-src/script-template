#!/bin/sh
# Generate vmlinux.h from the running kernel's BTF — the CO-RE header
# every BPF program in this project includes.
#
#   .build/gen-vmlinux.sh <bpftool> <output-path>

set -eu

BPFTOOL="${1:-bpftool}"
OUT="${2:-src/bpf/include/vmlinux.h}"

if [ ! -r /sys/kernel/btf/vmlinux ]; then
	echo "error: /sys/kernel/btf/vmlinux is not readable — kernel BTF (CONFIG_DEBUG_INFO_BTF) is required" >&2
	exit 1
fi

mkdir -p "$(dirname "$OUT")"
# bpftool prints a benign "skipping /sys/kernel/btf/vmlinux (will be loaded as
# base)" note to stderr even on success. Capture stderr and replay it only if
# the dump actually fails, so a normal build stays quiet.
if ! err="$("$BPFTOOL" btf dump file /sys/kernel/btf/vmlinux format c 2>&1 >"$OUT")"; then
	[ -n "$err" ] && printf '%s\n' "$err" >&2
	exit 1
fi
echo "generated $OUT"
