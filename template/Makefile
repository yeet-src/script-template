# Build the yeet script project.
#
#   make         — build everything (BPF objects + JS bundle)
#   make bpf     — compile bpf/*.bpf.c into bin/* only
#   make veristat — load the built object with veristat (verifier check on this kernel)
#   make bundle  — bundle the JS entry with esbuild
#   make postgen — finalize a freshly generated project (git init)
#   make clangd  — write a local .clangd pointing at the resolved toolchain
#   make clean   — remove build artifacts
#   make V=1     — show the commands behind the status lines
#
# This is the build *frontend*: it orchestrates two independent
# compilers — clang for the BPF objects, esbuild for the JS bundle.
# Neither understands the other; the JS references compiled objects in
# bin/ only by path, resolved at runtime. `yeet run` invokes `make`
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

all: bpf bundle
	@end=$$(date +%s%N 2>/dev/null); t=""; \
	case "$(BUILD_START)$$end" in \
		""|*[!0-9]*) ;; \
		*) t=" in $$(awk "BEGIN { printf \"%.2fs\", ($$end - $(BUILD_START)) / 1e9 }")" ;; \
	esac; \
	printf '$(STATUS_FMT)' 'Finished' "build$$t" >&2

# Bundle the entry with the vendored esbuild. esbuild honors tsconfig `paths`
# (so `@/` resolves at bundle time), while `yeet:*` builtins and `*.bpf.o`
# objects stay external. The bundle is written to dist/index.jsx: the entry
# ladder tries dist/ before src/, so once built, that is what runs — and the
# generated file stays out of the source tree (dist/ is gitignored).
# The .jsx extension keeps the bundle eligible for component auto-mount.
# Compiled BPF objects in bin/ are loaded by path at runtime, never imported,
# so they are not bundled.
#
# The build needs no npm/node: the starter imports only `yeet:*` builtins and
# local `@/` modules, which esbuild resolves on its own. If you add third-party
# packages to package.json, install them into node_modules with the package
# manager of your choice — esbuild inlines whatever it finds there.
ESBUILD_FLAGS := --bundle --format=esm --platform=neutral \
	--main-fields=module,main --conditions=import,module \
	--define:import.meta.main=false \
	--outfile=dist/index.jsx --jsx=automatic --jsx-import-source=yeet:tui

bundle: | toolchain
	$(Q)$(ESBUILD) src/main.jsx $(ESBUILD_FLAGS) --log-level=warning '--external:yeet:*' '--external:*.bpf.o'
	@printf '$(STATUS_FMT)' 'Bundling' "src/main.jsx -> dist/index.jsx ($$(wc -c < dist/index.jsx | awk '{ printf "%.1fkb", $$1 / 1024 }'))" >&2

# Post-generation finalize: initialize a git repository with the vendored git
# (fetched via `vendored-git`). Idempotent — skipped if this is already a repo.
# The scaffolders (`yeet new`, `scripts/new`) run `make postgen` after creating
# the project, so the CLI itself stays a thin caller of make.
postgen: | vendored-git
	@g="$(GIT)"; $$g --version >/dev/null 2>&1 || g="$$(command -v git 2>/dev/null || true)"; \
	if [ -e .git ]; then \
		printf '$(STATUS_FMT)' 'Skipping' 'git init (already a repository)' >&2; \
	elif [ -n "$$g" ]; then \
		printf '$(STATUS_FMT)' 'Initializing' 'git repository' >&2; \
		$$g -c init.templateDir= init -q . || printf '$(WARN_FMT)' 'git init failed' >&2; \
	else \
		printf '$(WARN_FMT)' 'no git available (vendored or host); skipping git init' >&2; \
	fi

clean: clean-bpf
	$(call status,Cleaning,node_modules dist)
	$(Q)rm -rf node_modules dist

.PHONY: all bundle clean postgen
