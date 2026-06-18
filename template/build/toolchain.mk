# Resolve the static build toolchain (clang, bpftool, esbuild) — included by
# the project Makefile before build/bpf.mk so CLANG/BPFTOOL/ESBUILD are set
# before any rule uses them.
#
# Three sources, in order; a `make CLANG=… ` CLI override beats all of them:
#
#   1. In-repo  — binaries committed under v/<uname -m>/ (a sibling of the
#      project). Used when hacking the bootstrap repo itself; no download.
#   2. Cache    — a shared, per-machine store keyed by the project's pinned
#      toolchain VERSION (build/toolchain.lock, stamped in by `yeet new`).
#      `make toolchain` fills it, downloading each missing tool exactly once.
#   3. PATH     — whatever clang/bpftool/esbuild the host already has.
#
# The cache key is the toolchain version, never the template version, and the
# download URLs are version-addressed — so updating the template reuses an
# existing cached toolchain, and bumping a tool version adds a new entry
# beside the old one instead of invalidating it. Existing projects keep
# building against the exact toolchain they were pinned to.

UNAME_M := $(shell uname -m)

# 1. In-repo binaries present under v/<arch>/ (a dev who built them locally).
# Match the clang binary itself, not just the dir — the binaries are gitignored
# (distributed via the cache), so a fresh clone has no v/<arch>/clang and falls
# through to the cache below.
VENDORED_CLANG := $(firstword $(wildcard ../v/$(UNAME_M)/clang ../../v/$(UNAME_M)/clang v/$(UNAME_M)/clang))

TOOLCHAIN_LOCK :=
ifneq ($(VENDORED_CLANG),)
  VENDORED := $(patsubst %/clang,%,$(VENDORED_CLANG))
  CLANG   ?= $(VENDORED)/clang
  BPFTOOL ?= $(VENDORED)/bpftool
  ESBUILD ?= $(VENDORED)/esbuild
  GIT     ?= $(VENDORED)/git
  # libbpf program headers (bpf_helpers.h, …) are SDK-level, not app source:
  # shared across arches under v/include, version-tied to bpftool/libbpf.
  BPF_SYSINCLUDE ?= $(dir $(VENDORED))include
else
  # 2. Shared per-machine cache, keyed by the pinned toolchain version. A
  # scaffolded project carries build/toolchain.lock; building the bootstrap
  # repo itself falls back to the canonical pins one level up so it, too,
  # needs no committed binaries.
  TOOLCHAIN_LOCK := $(firstword $(wildcard build/toolchain.lock ../v/build/versions.env))
  ifneq ($(TOOLCHAIN_LOCK),)
    include $(TOOLCHAIN_LOCK)
    TOOLCHAIN_KEY  := llvm$(LLVM_VERSION)-bpftool$(BPFTOOL_VERSION)-esbuild$(ESBUILD_VERSION)-make$(MAKE_VERSION)-git$(GIT_VERSION)
    YEET_CACHE_DIR ?= $(if $(XDG_CACHE_HOME),$(XDG_CACHE_HOME),$(HOME)/.cache)/yeet
    TOOLCHAIN_DIR  := $(YEET_CACHE_DIR)/toolchain/$(TOOLCHAIN_KEY)/$(UNAME_M)
    CLANG   ?= $(TOOLCHAIN_DIR)/clang
    BPFTOOL ?= $(TOOLCHAIN_DIR)/bpftool
    ESBUILD ?= $(TOOLCHAIN_DIR)/esbuild
    GIT     ?= $(TOOLCHAIN_DIR)/git
    # Headers are arch-independent: one copy per version key, beside the
    # per-arch tool dirs.
    BPF_SYSINCLUDE ?= $(YEET_CACHE_DIR)/toolchain/$(TOOLCHAIN_KEY)/include
  endif
endif

# 3. PATH fallbacks (bpf.mk supplies the clang/bpftool fallbacks).
ESBUILD ?= esbuild
GIT     ?= git

# Ensure the cache holds this arch's tools, fetching any that are missing.
# A no-op for the in-repo and PATH cases (nothing to download).
.PHONY: toolchain
toolchain:
ifneq ($(TOOLCHAIN_LOCK),)
	@sh build/fetch-toolchain.sh "$(TOOLCHAIN_DIR)" "$(UNAME_M)" "$(TOOLCHAIN_LOCK)"
else
	@:
endif

# Fetch only git into the cache — used by the `postgen` target so generating a
# project doesn't pull the whole build toolchain just to initialize a repo.
.PHONY: vendored-git
vendored-git:
ifneq ($(TOOLCHAIN_LOCK),)
	@sh build/fetch-toolchain.sh "$(TOOLCHAIN_DIR)" "$(UNAME_M)" "$(TOOLCHAIN_LOCK)" git \
		|| echo "note: vendored git unavailable; postgen will fall back to host git" >&2
else
	@:
endif
