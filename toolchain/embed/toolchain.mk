# Resolve the static build toolchain (clang, bpftool, veristat, esbuild, git, gh) — included
# by the project Makefile before build/bpf.mk, so the tools are set before any
# rule uses them. A `make CLANG=…` CLI override beats this.
#
# Two sources, tried in this order:
#
#  1. The yeet CLI's managed toolchain. When `yeet` is on PATH, each tool runs
#     as `yeet toolchain exec <tool>` — from whichever toolchain `yeet toolchain
#     default` points at (`yeet toolchain list` shows it). The build then
#     shares yeet's single install instead of filling a second cache, and
#     `yeet toolchain update` moves the build along with it. If none is
#     installed yet, the `toolchain` target installs the version pinned in
#     build/toolchain.lock (latest without a lock) and makes it the default;
#     it only notes a mismatch when a default already exists. Build with
#     `make YEET=` to skip this source.
#
#  2. A shared, per-machine cache keyed by the project's pinned toolchain
#     version (build/toolchain.lock). `make toolchain` fills it, downloading
#     each missing tool once from the vendored toolchain release
#     (github.com/yeet-src/toolchain). The cache key is the toolchain version,
#     never the template version — so updating the template reuses an
#     existing cached toolchain, and bumping a tool adds a new entry beside
#     the old one. This is what CI and hosts without yeet use.
#
# Falls back to host tools on PATH when neither applies (no yeet, no lock).
#
# The vendored binaries are Linux musl-static, so both sources are Linux-only.
# On any other host (macOS, BSD) we leave CLANG/BPFTOOL/ESBUILD/GIT/GH unset,
# falling through to host tools on PATH — macOS is an edit-here,
# build-on-Linux host for BPF work.

# Status-line formats, normally set by the project's build/ui.mk (included
# before this file); these fallbacks keep the glue usable on its own. Exported
# so build/fetch-toolchain.sh prints the same way.
STATUS_FMT ?= * %-10s %s\n
WARN_FMT   ?= ! %s\n
ERROR_FMT  ?= x %s\n
export STATUS_FMT WARN_FMT ERROR_FMT

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)
# Apple/BSD report arm64; the release assets are named aarch64. Normalize so
# the cache key and asset names line up across hosts.
UNAME_M := $(UNAME_M:arm64=aarch64)

# Only engage the vendored toolchain on Linux; elsewhere YEET and
# TOOLCHAIN_LOCK stay empty so the PATH fallbacks below win and the fetch
# targets become no-ops.
ifeq ($(UNAME_S),Linux)
YEET           ?= $(shell command -v yeet 2>/dev/null)
TOOLCHAIN_LOCK := $(firstword $(wildcard build/toolchain.lock))
endif
ifneq ($(TOOLCHAIN_LOCK),)
  include $(TOOLCHAIN_LOCK)
  TOOLCHAIN_KEY := v$(TOOLCHAIN_VERSION)
endif

ifneq ($(YEET),)
  # --- source 1: the yeet-managed toolchain ---------------------------------
  YEET_EXEC      := $(YEET) toolchain exec
  TOOLCHAIN_WANT := $(if $(TOOLCHAIN_KEY),$(TOOLCHAIN_KEY),latest)
  # Where the active toolchain lives — ask its clang for its own path. Needed
  # for the libbpf headers (-I), `make clangd`, qemu, and veristat (the kernel
  # matrix copies the binary into a VM, so it must be a file, not an exec
  # wrapper). Resolved lazily, on first use, and memoized: the `toolchain`
  # target may install the toolchain first, and every rule that needs the
  # path runs after it (order-only `| toolchain`), while targets that don't
  # (clean, postgen) never trigger a lookup. Empty if nothing is installed.
  TOOLCHAIN_DIR    = $(eval TOOLCHAIN_DIR := $(dir $(shell $(YEET_EXEC) clang -print-prog-name=clang 2>/dev/null)))$(TOOLCHAIN_DIR)
  TOOLCHAIN_ACTIVE = $(notdir $(patsubst %/,%,$(TOOLCHAIN_DIR)))
  CLANG    ?= $(YEET_EXEC) clang
  BPFTOOL  ?= $(YEET_EXEC) bpftool
  ESBUILD  ?= $(YEET_EXEC) esbuild
  GIT      ?= $(YEET_EXEC) git
  GH       ?= $(YEET_EXEC) gh
  VERISTAT       ?= $(TOOLCHAIN_DIR)veristat
  BPF_SYSINCLUDE ?= $(TOOLCHAIN_DIR)libbpf-headers
else ifneq ($(TOOLCHAIN_LOCK),)
  # --- source 2: the lock-pinned shared cache -------------------------------
  YEET_CACHE_DIR ?= $(if $(XDG_CACHE_HOME),$(XDG_CACHE_HOME),$(HOME)/.cache)/yeet
  TOOLCHAIN_DIR  := $(YEET_CACHE_DIR)/toolchain/$(TOOLCHAIN_KEY)/$(UNAME_M)
  CLANG    ?= $(TOOLCHAIN_DIR)/clang
  BPFTOOL  ?= $(TOOLCHAIN_DIR)/bpftool
  VERISTAT ?= $(TOOLCHAIN_DIR)/veristat
  ESBUILD  ?= $(TOOLCHAIN_DIR)/esbuild
  GIT      ?= $(TOOLCHAIN_DIR)/git
  GH       ?= $(TOOLCHAIN_DIR)/gh
  # libbpf program headers are arch-independent: one copy per version key,
  # beside the per-arch tool dirs.
  BPF_SYSINCLUDE ?= $(YEET_CACHE_DIR)/toolchain/$(TOOLCHAIN_KEY)/include
endif

# PATH fallbacks (bpf.mk supplies the clang/bpftool fallbacks).
VERISTAT ?= veristat
ESBUILD  ?= esbuild
GIT      ?= git
GH       ?= gh

# Make the toolchain ready for this arch. With yeet: install one if none is
# present (the pinned version, as the default) and note a mismatch against the
# lock's pin otherwise. With the cache: download any missing tool once. A
# no-op when neither applies (PATH case).
#
# The yeet branch works in shell, not via $(TOOLCHAIN_DIR): make expands a
# whole recipe before running it, so expanding the lazy lookup here would
# memoize "not installed" before the install line had run.
.PHONY: toolchain
toolchain:
ifneq ($(YEET),)
	@$(YEET_EXEC) clang -print-prog-name=clang >/dev/null 2>&1 || { \
		printf '$(STATUS_FMT)' 'install' 'yeet toolchain $(TOOLCHAIN_WANT) (none installed yet)' >&2; \
		$(YEET) toolchain install $(TOOLCHAIN_WANT) --default; }
	@d="$$($(YEET_EXEC) clang -print-prog-name=clang)"; d="$${d%/*}"; v="$${d##*/}"; \
	printf '$(STATUS_FMT)' 'toolchain' "$$v  ~$${d#$$HOME}" >&2; \
	if [ -n "$(TOOLCHAIN_KEY)" ] && [ "$$v" != "$(TOOLCHAIN_KEY)" ]; then \
		printf '$(WARN_FMT)' "yeet's default toolchain is $$v but build/toolchain.lock pins $(TOOLCHAIN_KEY) — 'yeet toolchain default $(TOOLCHAIN_KEY)' to match it, or 'make YEET=' to build from the pinned cache" >&2; \
	fi
else ifneq ($(TOOLCHAIN_LOCK),)
	@sh build/fetch-toolchain.sh "$(TOOLCHAIN_DIR)" "$(UNAME_M)" "$(TOOLCHAIN_LOCK)"
else
	@:
endif

# Fetch only git into the cache — used by `postgen` so generating a project
# doesn't pull the whole build toolchain just to initialize a repo. Nothing to
# fetch with yeet: its git is there if any toolchain is, and postgen falls
# back to host git otherwise.
.PHONY: vendored-git
vendored-git:
ifeq ($(YEET),)
ifneq ($(TOOLCHAIN_LOCK),)
	@sh build/fetch-toolchain.sh "$(TOOLCHAIN_DIR)" "$(UNAME_M)" "$(TOOLCHAIN_LOCK)" git \
		|| printf '$(WARN_FMT)' 'vendored git unavailable; postgen will fall back to host git' >&2
endif
endif
	@:
