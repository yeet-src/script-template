.PHONY: new help sync-toolchain

.DEFAULT_GOAL := help

# The static build toolchain (clang, bpftool, esbuild, make, git) lives in its
# own repo, yeet-src/toolchain, vendored here under toolchain/ and pinned to a
# release tag. The template payload doesn't read toolchain/ directly — it
# carries its own copies under template/.build/ (the embed glue + a
# toolchain.lock) so a generated project stays self-contained. `sync-toolchain`
# refreshes both from a tag.
TOOLCHAIN_REPO ?= git@github.com:yeet-src/toolchain.git
TOOLCHAIN_TAG  ?= v0.1

new:
	@scripts/new "$(DEST)" $(NAME)

# Update the vendored toolchain to TOOLCHAIN_TAG and re-sync the payload.
#   make sync-toolchain TOOLCHAIN_TAG=v0.2
#
# This replaces toolchain/ wholesale with the tag's tree (via `git archive`, NOT
# `git subtree pull`) and lands the whole update as ONE normal commit — so the
# branch is always rebase-mergeable. `git subtree pull` would instead create a
# merge commit, which this repo's rebase-only merge policy rejects. The
# git-subtree-* trailers are kept for provenance and `git subtree pull` compat.
#
# Run it on a branch off master, then open a PR. It refuses a dirty tree so the
# commit is exactly the bump. NOTE: a local patch carried ahead of a tag (e.g.
# an unreleased fix) is overwritten — only sync to a tag that already contains
# the changes you want.
sync-toolchain:
	@git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "error: not a git repo" >&2; exit 1; }
	@git diff --quiet && git diff --cached --quiet || { \
		echo "error: working tree dirty — commit or stash first so the sync lands as one clean commit" >&2; \
		exit 1; }
	@echo ">> fetching toolchain $(TOOLCHAIN_TAG) from $(TOOLCHAIN_REPO)"
	@git fetch --depth=1 $(TOOLCHAIN_REPO) $(TOOLCHAIN_TAG)
	@split=$$(git rev-parse FETCH_HEAD); \
	echo ">> replacing toolchain/ with $(TOOLCHAIN_TAG) ($$split)"; \
	rm -rf toolchain && mkdir toolchain && git archive FETCH_HEAD | tar -x -C toolchain; \
	: 'The embed glue assumes the machinery dir is named build/; we vendor it'; \
	: 'into .build/, so rewrite that path prefix as we copy (keeps the sync'; \
	: 'robust no matter what the upstream toolchain names it). We also gate the'; \
	: 'always-on "toolchain ready" summary behind YEET_TOOLCHAIN_QUIET so a'; \
	: 'normal build stays quiet (pretty.mk sets it; V=1 shows it). If upstream'; \
	: 'reworks that line the gate simply no-ops and the summary returns.'; \
	sed 's|build/|.build/|g' toolchain/embed/toolchain.mk       > template/.build/toolchain.mk; \
	sed -e 's|build/|.build/|g' \
	    -e 's#^echo ">> toolchain ready:#[ -n "$${YEET_TOOLCHAIN_QUIET:-}" ] || echo ">> toolchain ready:#' \
	    toolchain/embed/fetch-toolchain.sh > template/.build/fetch-toolchain.sh; \
	cp toolchain/build/versions.env       template/.build/toolchain.lock; \
	git add -A toolchain template/.build/toolchain.mk template/.build/fetch-toolchain.sh template/.build/toolchain.lock; \
	if git diff --cached --quiet; then \
		echo ">> already at $(TOOLCHAIN_TAG) — nothing to commit"; \
	else \
		printf '%s\n\n%s\n\n%s\n%s\n' \
			"toolchain: sync vendored $(TOOLCHAIN_TAG)" \
			"Single non-merge commit (archive replace, not subtree pull) so the update stays rebase-mergeable." \
			"git-subtree-dir: toolchain" \
			"git-subtree-split: $$split" | git commit -q -F -; \
		echo ">> committed sync of $(TOOLCHAIN_TAG) as one commit — open a PR and rebase-merge"; \
	fi

help:
	@echo 'make new DEST=<dir> [NAME=<name>]         — create a new yeet script'
	@echo 'scripts/new <dir> [name]                  — same, without make'
	@echo 'make sync-toolchain [TOOLCHAIN_TAG=vX.Y]  — update vendored toolchain (one rebase-mergeable commit)'
