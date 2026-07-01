# Low-level build machinery for the yeet script project — the back end behind
# `yeet build`. It and its siblings (bpf.mk, toolchain.mk, the shell scripts,
# toolchain.lock) live under .build/, which a generated project gitignores
# wholesale; `yeet build` (or the thin root Makefile shim, which forwards
# `make` here from the project root) drives it. Every path below is written
# relative to the *project root*, since that stays the working directory:
#
#   yeet build          — build everything (BPF objects + JS bundle)  [= all]
#   make bpf            — compile bpf/*.bpf.c into bin/* only
#   make veristat       — load the built object with veristat (verifier check on this kernel)
#   make bundle         — bundle the JS entry with esbuild
#   make postgen        — finalize a freshly generated project (git init)
#   make clangd         — write a local .clangd pointing at the resolved toolchain
#   make clean          — remove build artifacts
#
# This is the build *frontend* logic: it orchestrates two independent
# compilers — clang for the BPF objects, esbuild for the JS bundle.
# Neither understands the other; the JS references compiled objects in
# bin/ only by path, resolved at runtime. `yeet run` invokes the build
# automatically when running this project from a trusted remote source,
# so the default goal must leave the project runnable.
#
# clang, bpftool and esbuild come from the static toolchain resolved by
# .build/toolchain.mk (a shared per-machine cache, or binaries vendored in
# the bootstrap repo) — so the build needs no system C/BPF toolchain.

.DEFAULT_GOAL := all

include .build/pretty.mk
include .build/toolchain.mk
include .build/bpf.mk

# `banner` prints first (leftmost prerequisite, built before bpf/bundle in a
# serial build) and the recipe's summary prints last, so a build reads as a
# titled progress list. Both are cheap, so they show even on an up-to-date
# build — a consistent frame around whatever work actually ran.
all: banner bpf bundle
	@b=$(BPF_OUT); j=dist/index.jsx; \
	bs=$$(wc -c <"$$b" 2>/dev/null || echo 0); js=$$(wc -c <"$$j" 2>/dev/null || echo 0); \
	$(SAY) done "$$(printf '%s (%d KiB) · %s (%d KiB)' "$$b" "$$((bs/1024))" "$$j" "$$((js/1024))")"

banner:
	@$(SAY) head "building $(notdir $(CURDIR))"

# Bundle the entry with the vendored esbuild. esbuild honors tsconfig `paths`
# (so `@/` resolves at bundle time), while `yeet:*` builtins and `*.bpf.o`
# objects stay external. The bundle is written to dist/index.jsx (a gitignored
# build-output dir), which the entry resolver prefers over the raw src/main.jsx
# — so once built, that is what `yeet run .` runs. The .jsx extension keeps the
# bundle eligible for component auto-mount.
# Compiled BPF objects in bin/ are loaded by path at runtime, never imported,
# so they are not bundled.
#
# The build needs no npm/node: the starter imports only `yeet:*` builtins and
# local `@/` modules, which esbuild resolves on its own. If you add third-party
# packages to package.json, install them into node_modules with the package
# manager of your choice — esbuild inlines whatever it finds there.
# `--log-level=warning` drops esbuild's own success summary (the outfile/size
# line and "Done in Nms") so the build shows just our one `bundle` step — real
# warnings and errors still print.
#
# `--define:import.meta.main=false` compiles out the `import.meta.main`
# self-test guards (see AGENTS.md). Bundling collapses every module into one
# file that shares the entry's `import.meta`, so without this each guarded
# block would see `main === true` and all fire at once in the built app;
# defined to false they become `if (false)` and drop. A standalone
# `yeet run src/probes/foo.js` isn't bundled, so its guard still runs.
ESBUILD_FLAGS := --bundle --format=esm --platform=neutral \
	--main-fields=module,main --conditions=import,module --log-level=warning \
	--define:import.meta.main=false \
	--outfile=dist/index.jsx --jsx=automatic --jsx-import-source=yeet:tui

bundle: | toolchain
	@$(SAY) step bundle "src/main.jsx → dist/index.jsx"
	$(Q)$(ESBUILD) src/main.jsx $(ESBUILD_FLAGS) '--external:yeet:*' '--external:*.bpf.o'

# Post-generation finalize: initialize a git repository with the vendored git
# (fetched via `vendored-git`). Idempotent — skipped if this is already a repo.
# The scaffolders (`yeet new`, `scripts/new`) run `make postgen` after creating
# the project, so the CLI itself stays a thin caller of make.
postgen: | vendored-git
	@g="$(GIT)"; [ -x "$$g" ] || g="$$(command -v git 2>/dev/null || true)"; \
	if [ -e .git ]; then \
		echo "postgen: already a git repository"; \
	elif [ -n "$$g" ]; then \
		echo "postgen: git init"; \
		"$$g" -c init.templateDir= init -q . || echo "warning: 'git init' failed" >&2; \
	else \
		echo "warning: no git available (vendored or host); skipping 'git init'" >&2; \
	fi

clean: clean-bpf
	rm -rf node_modules dist

.PHONY: all banner bundle clean postgen
