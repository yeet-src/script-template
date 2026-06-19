# script-template

Template for new yeet scripts. Scaffold one with:

```sh
make new DEST=<dir> [NAME=<name>]      # or: scripts/new <dir> [name]
```

The static build toolchain (clang, bpftool, esbuild, make, git) lives in its own
repo, [yeet-src/toolchain](https://github.com/yeet-src/toolchain), vendored here
under `toolchain/` and pinned to a release tag. Generated projects don't read
`toolchain/` — they carry their own copies under `template/build/` (the embed
glue + a `toolchain.lock`). Refresh both from a toolchain release with:

```sh
make sync-toolchain TOOLCHAIN_TAG=v0.8.0      # one rebase-mergeable commit; open a PR
```

## Releasing

Every push to `master` publishes a versioned snapshot release and marks it
GitHub **"Latest"**, so `.../releases/latest/download/<asset>` always tracks the
newest build (no separate rolling tag — GitHub's built-in Latest is the single
source of truth). Versions are semver `vMAJOR.MINOR.PATCH`; CI picks the bump
from a `[bump:LEVEL]` marker in the commit **subject** (the body is free prose —
put the marker on the subject line, like `[skip ci]`; for squash merges that's
the PR title):

| Marker | Bump | Notes |
| --- | --- | --- |
| *(none)* or `[bump:minor]` | **minor** `X.Y+1.0` | the default — a normal push |
| `[bump:patch]` | **patch** `X.Y.Z+1` | only if **every** commit in the release range is `[bump:patch]` |
| `[bump:major]` | **major** `X+1.0.0` | one such commit makes the whole release major |

The release takes the highest level any commit asks for. A PR check
([`commit-convention.yml`](.github/workflows/commit-convention.yml)) rejects
malformed markers (e.g. `[bump:pacth]`) before merge, so a typo can't silently
mis-version a release.

### Back-patching an older line

To ship a fix on an older release while `master` has moved on, fork the line
from its tag and PR fixes into it:

```sh
git branch release/v0.8 v0.8.0 && git push origin release/v0.8
# open a PR against release/v0.8, then rebase-merge
```

A push to `release/*` runs the same workflow but scopes the version **by name**
to that line's tags, so a fix on `release/v0.8` publishes `v0.8.1` independent of
`master`. On `release/*` an unmarked commit defaults to a **patch** bump (not
minor) so a hotfix can't collide with a mainline tag. Maintenance branches are
**manual** here (not auto-opened) — master releases on every push, so
auto-opening a branch per minor would create one per push.
