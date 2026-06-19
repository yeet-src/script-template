.PHONY: new help sync-toolchain

.DEFAULT_GOAL := help

# The static build toolchain (clang, bpftool, esbuild, make, git) lives in its
# own repo, yeet-src/toolchain, vendored here as a git subtree under toolchain/
# and pinned to a release tag (currently v0.1). The template payload doesn't
# read toolchain/ directly — it carries its own copies under template/build/
# (the embed glue + a toolchain.lock) so a generated project stays
# self-contained. `sync-toolchain` refreshes those copies from the subtree.
TOOLCHAIN_TAG ?= v0.1

new:
	@scripts/new "$(DEST)" $(NAME)

# Refresh the vendored toolchain and re-sync the template's payload copies.
#   make sync-toolchain                      — re-copy from the current subtree
#   make sync-toolchain TOOLCHAIN_TAG=v0.2   — pull a newer release, then copy
# The pull is best-effort and only runs on a clean tree (subtree merges refuse
# a dirty one); the copy is what keeps template/build/ in lockstep.
sync-toolchain:
	@if git diff --quiet && git diff --cached --quiet; then \
		echo ">> git subtree pull --prefix=toolchain ($(TOOLCHAIN_TAG))"; \
		git subtree pull --prefix=toolchain \
			git@github.com:yeet-src/toolchain.git $(TOOLCHAIN_TAG) --squash || true; \
	else \
		echo ">> working tree dirty — skipping subtree pull, syncing from current toolchain/"; \
	fi
	@cp toolchain/embed/toolchain.mk       template/build/toolchain.mk
	@cp toolchain/embed/fetch-toolchain.sh template/build/fetch-toolchain.sh
	@cp toolchain/build/versions.env       template/build/toolchain.lock
	@echo ">> synced embed glue + toolchain.lock into template/build/"

help:
	@echo 'make new DEST=<dir> [NAME=<name>]         — create a new yeet script'
	@echo 'scripts/new <dir> [name]                  — same, without make'
	@echo 'make sync-toolchain [TOOLCHAIN_TAG=vX.Y]  — refresh vendored toolchain → template/build/'
