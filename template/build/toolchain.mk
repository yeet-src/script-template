# Resolve the static build toolchain (clang, bpftool, esbuild, git) — included
# by the project Makefile before build/bpf.mk, so the tools are set before any
# rule uses them. A `make CLANG=…` CLI override beats this.
#
# Tools come from a shared, per-machine cache keyed by the project's pinned
# toolchain version (build/toolchain.lock). `make toolchain` fills it,
# downloading each missing tool once from the vendored toolchain release
# (github.com/yeet-src/toolchain). The cache key is the toolchain version,
# never the template version — so updating the template reuses an existing
# cached toolchain, and bumping a tool adds a new entry beside the old one.
# Falls back to host tools on PATH when no lock is present.

UNAME_M := $(shell uname -m)

TOOLCHAIN_LOCK := $(firstword $(wildcard build/toolchain.lock))
ifneq ($(TOOLCHAIN_LOCK),)
  include $(TOOLCHAIN_LOCK)
  TOOLCHAIN_KEY  := llvm$(LLVM_VERSION)-bpftool$(BPFTOOL_VERSION)-esbuild$(ESBUILD_VERSION)-make$(MAKE_VERSION)-git$(GIT_VERSION)
  YEET_CACHE_DIR ?= $(if $(XDG_CACHE_HOME),$(XDG_CACHE_HOME),$(HOME)/.cache)/yeet
  TOOLCHAIN_DIR  := $(YEET_CACHE_DIR)/toolchain/$(TOOLCHAIN_KEY)/$(UNAME_M)
  CLANG   ?= $(TOOLCHAIN_DIR)/clang
  BPFTOOL ?= $(TOOLCHAIN_DIR)/bpftool
  ESBUILD ?= $(TOOLCHAIN_DIR)/esbuild
  GIT     ?= $(TOOLCHAIN_DIR)/git
  # libbpf program headers are arch-independent: one copy per version key,
  # beside the per-arch tool dirs.
  BPF_SYSINCLUDE ?= $(YEET_CACHE_DIR)/toolchain/$(TOOLCHAIN_KEY)/include
endif

# PATH fallbacks (bpf.mk supplies the clang/bpftool fallbacks).
ESBUILD ?= esbuild
GIT     ?= git

# Fill the cache for this arch, downloading any missing tool once. A no-op
# when no lock is present (PATH case).
.PHONY: toolchain
toolchain:
ifneq ($(TOOLCHAIN_LOCK),)
	@sh build/fetch-toolchain.sh "$(TOOLCHAIN_DIR)" "$(UNAME_M)" "$(TOOLCHAIN_LOCK)"
else
	@:
endif

# Fetch only git into the cache — used by `postgen` so generating a project
# doesn't pull the whole build toolchain just to initialize a repo.
.PHONY: vendored-git
vendored-git:
ifneq ($(TOOLCHAIN_LOCK),)
	@sh build/fetch-toolchain.sh "$(TOOLCHAIN_DIR)" "$(UNAME_M)" "$(TOOLCHAIN_LOCK)" git \
		|| echo "note: vendored git unavailable; postgen will fall back to host git" >&2
else
	@:
endif
