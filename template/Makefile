# Build the yeet script project.
#
#   make         — build everything (BPF objects + JS bundle)
#   make bpf     — compile bpf/*.bpf.c into dist/bin/probe.bpf.o only
#   make veristat — load the built object with veristat (verifier check on this kernel)
#   make bundle  — bundle the JS entry with esbuild
#   make pkg     — pack dist/ into pkg/<name>-<version>.tar.gz, the shippable artifact
#   make postgen — finalize a freshly generated project (git init)
#   make clangd  — write a local .clangd pointing at the resolved toolchain
#   make clean   — remove build artifacts
#   make V=1     — show the commands behind the status lines
#
# This is the build *frontend*: it orchestrates two independent
# compilers — clang for the BPF objects, esbuild for the JS bundle.
# Neither understands the other; the JS references compiled objects in
# dist/ only by path, resolved at runtime. `yeet run` invokes `make`
# automatically when running this project from a trusted remote source,
# so the default goal must leave the project runnable.
#
# clang, bpftool and esbuild come from the static toolchain resolved by
# build/toolchain.mk (the yeet CLI's installed toolchain when `yeet` is on
# PATH, else a shared per-machine cache pinned by build/toolchain.lock) — so
# the build needs no system C/BPF toolchain.

.DEFAULT_GOAL := all

include build/ui.mk
include build/toolchain.mk
include build/bpf.mk

BUILD_START := $(shell date +%s%N 2>/dev/null)

# The project name and version, from package.json (the scaffold sets the
# name); the directory name and 0.0.0 as fallbacks.
NAME    := $(or $(shell sed -n 's/^  "name": "\(.*\)",$$/\1/p' package.json),$(notdir $(CURDIR)))
VERSION := $(or $(shell sed -n 's/^  "version": "\(.*\)",$$/\1/p' package.json),0.0.0)
TARBALL := pkg/$(NAME)-$(VERSION).tar.gz

all: bpf bundle
	$(call done,$(NAME))
	$(call artifact,$(BPF_OUT))
	$(call artifact,dist/index.js)

# Bundle the entry with the vendored esbuild. esbuild honors tsconfig `paths`
# (so `#/` resolves at bundle time), while `yeet:*` builtins and `*.bpf.o`
# objects stay external. The bundle is written to dist/index.js: the entry
# ladder tries dist/ before src/, so once built, that is what runs — and the
# generated file stays out of the source tree (dist/ is gitignored). Plain
# .js is fine: JSX is compiled away by esbuild, and src/main.jsx mounts its
# root component explicitly, so the bundle needs no auto-mount.
# Compiled BPF objects are imported as "#/bin/<name>.bpf.o" (see
# src/probes/probe.js) and stay external: the alias rewrites the "#/bin"
# prefix to ./bin, relative to the bundle, so every object import points
# beside the bundle and a copied dist/ (index.js + bin/) runs on its own
# with no manifest. (`\#`: a bare # would start a make comment.)
#
# The build needs no npm/node: the starter imports only `yeet:*` builtins and
# local `#/` modules, which esbuild resolves on its own. If you add third-party
# packages to package.json, install them into node_modules with the package
# manager of your choice — esbuild inlines whatever it finds there.
ESBUILD_FLAGS := --bundle --format=esm --platform=neutral \
	--main-fields=module,main --conditions=import,module \
	--define:import.meta.main=false \
	--outfile=dist/index.js --jsx=automatic --jsx-import-source=yeet:tui \
	'--alias:\#/bin=./bin'

bundle: | toolchain
	$(call step,bundle,dist/index.js,$(ESBUILD) src/main.jsx $(ESBUILD_FLAGS) --log-level=warning '--external:yeet:*' '--external:*.bpf.o')

# The shippable artifact: all of dist/ (index.js + bin/) as
# pkg/<name>-<version>.tar.gz. Entries are relative (./index.js,
# ./bin/probe.bpf.o), so it unpacks into any directory you choose, and
# `yeet run .` there runs it. Not part of the default build — `yeet run`
# needs only dist/ — so it's a separate target. pkg/ holds one package per
# version built; bump "version" in package.json to cut a new one.
pkg: bpf bundle
	$(call step,pkg,$(TARBALL),mkdir -p pkg && tar -czf $(TARBALL) -C dist .)
	$(call done,$(NAME))
	$(call artifact,$(TARBALL))

# Post-generation finalize: initialize a git repository with the vendored git
# (fetched via `vendored-git`). Idempotent — skipped if this is already a repo.
# The scaffolders (`yeet new`, `scripts/new`) run `make postgen` after creating
# the project, so the CLI itself stays a thin caller of make.
postgen: | vendored-git
	@g="$(GIT)"; $$g --version >/dev/null 2>&1 || g="$$(command -v git 2>/dev/null || true)"; \
	if [ -e .git ]; then \
		printf '$(STATUS_FMT)' 'git' 'already a repository' >&2; \
	elif [ -n "$$g" ]; then \
		printf '$(STATUS_FMT)' 'git' 'initialized repository' >&2; \
		$$g -c init.templateDir= init -q . || printf '$(WARN_FMT)' 'git init failed' >&2; \
	else \
		printf '$(WARN_FMT)' 'no git available (vendored or host); skipping git init' >&2; \
	fi

clean: clean-bpf
	$(call status,clean,node_modules)
	$(call status,clean,dist)
	$(call status,clean,pkg)
	$(Q)rm -rf node_modules dist pkg

.PHONY: all bundle pkg clean postgen
