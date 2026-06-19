# toolchain

<p align="center">
  <img src="docs/st-ignucius.jpg" alt="St. IGNUcius blesses your static build" width="320"><br>
  <em>St. IGNUcius blesses your statically-linked build.</em>
</p>

Static, version-pinned build tools for yeet scripts, so a project's `make`
runs with **no system C/BPF toolchain** installed. This repo *produces and
publishes* the toolchain; consumers (e.g. `script-template`) fetch it on demand
into a shared per-machine cache.

## What it ships

Each tool is a fully-static binary (no shared-library deps), built or fetched
per arch (`x86_64`, `aarch64`) and published on an immutable, semver-tagged
release **`vMAJOR.MINOR.PATCH`** (`v0.6.0`, `v0.6.1`, …). The tag carries the
version, so the assets are plain-named (`clang-x86_64`, `make-aarch64`, …); a
consumer pins one version.

CI picks the bump from the commits since the last release, via a `[bump:LEVEL]`
marker in the commit **subject** (the body is free prose — put the marker on the
subject line, like `[skip ci]`; for squash merges that's the PR title):

| Marker | Bump | Notes |
| --- | --- | --- |
| *(none)* or `[bump:minor]` | **minor** `X.Y+1.0` | the default — a normal push |
| `[bump:patch]` | **patch** `X.Y.Z+1` | only if **every** commit in the release range is `[bump:patch]` |
| `[bump:major]` | **major** `X+1.0.0` | one such commit makes the whole release major |

The release takes the highest level any commit asks for. A PR check
(`commit-convention.yml`) rejects malformed markers (e.g. `[bump:pacth]`)
before merge, so a typo can't silently mis-version a release.

| tool      | for                                                | source |
|-----------|----------------------------------------------------|--------|
| `clang`   | compile `*.bpf.c` (`-target bpf`)                  | built from LLVM source, musl-static |
| `make`    | drive the build                                    | built from GNU make source, musl-static |
| `git`     | `git init` a generated project                     | built from git source, musl-static, lean (no https) |
| `bpftool` | `vmlinux.h` (BTF dump) + link BPF objects          | official static release, re-hosted |
| `veristat`| check `*.bpf.o` load + BPF verifier statistics     | official static release, re-hosted |
| `esbuild` | bundle the JS entry                                | official static (Go) binary, re-hosted |
| `bpf/*.h` | libbpf program headers (`<bpf/bpf_helpers.h>`, …)  | libbpf bundled with bpftool |

The table above is the **build** toolchain — what `make` resolves. The same
release also carries two assets for the optional kernel-matrix *test* runner —
**not** build tools (they need host KVM + root, so `make` never touches them;
the test harness fetches them on demand):

- **qemu** (`qemu-<arch>.tar.gz`) — built from source like clang, then trimmed
  to the binary plus the few firmware blobs its machine loads (see
  [`build/Dockerfile.qemu`](build/Dockerfile.qemu)).
- **lvh** (`lvh-<arch>`) — [cilium's little-vm-helper](https://github.com/cilium/little-vm-helper),
  which boots the kernel images qemu runs. A single static Go binary distributed
  only as an OCI image, so it's re-hosted like bpftool (see
  [`build/fetch-lvh.sh`](build/fetch-lvh.sh)). Bundling it lets the runner skip a
  docker bootstrap.

```
build/      reproducible recipe — Dockerfile.{clang,make,git,qemu}, build-*.sh,
            fetch-*.sh, versions.env (pins + checksums)
include/    arch-independent libbpf SDK headers (source for the headers tarball)
embed/      the glue a template carries: toolchain.mk + fetch-toolchain.sh
.github/    vendor.yml — builds on native runners and publishes the release
```

Built binaries (`x86_64/`, `aarch64/`) are **not committed** — they're the
release assets. Only the recipe, headers, and embed glue are tracked.

## Consuming it

A template carries the [`embed/`](embed/) glue plus a `toolchain.lock`
(a copy of [`build/versions.env`](build/versions.env): pins + checksums +
`TOOLCHAIN_BASE_URL`). The project's `build/toolchain.mk` resolves each tool
from the cache, and `build/fetch-toolchain.sh` downloads any missing one (once)
from this repo's release, checksum-verified. Pull updates with
`git subtree pull` (or copy `embed/` + `build/versions.env`).

## Releasing

Change a tool pin in [`build/versions.env`](build/versions.env) and push — the
[`vendor-toolchain`](.github/workflows/vendor.yml) workflow rebuilds clang/make/
git (and the test-runner qemu) on native x86_64 and arm64 runners, re-hosts
bpftool/veristat/lvh/esbuild/headers,
**computes the next semver tag** (highest existing, bumped by the level the
commit messages ask for — minor by default), publishes all assets to
that immutable release, and records the version + checksums into `versions.env`.
The version bumps only when this repo changes, so consumers re-fetch only on a
real toolchain change.

### Back-patching an older line

Every time `master` cuts a new line (`vX.Y.0`), CI **auto-opens** the
`release/vX.Y` maintenance branch at that commit (patches and flavor builds
don't open a line). So to ship a fix on an older release while `master` has
moved on, just PR it into the existing branch:

```
# release/v0.6 already exists (opened when v0.6.0 was cut)
# open a PR against release/v0.6, then merge (rebase)
```

A push to `release/*` runs the same workflow, but the version is scoped **by
name** to that line's tags — so a fix on `release/v0.6` publishes `v0.6.1`,
independent of whatever `master` is on. On `release/*` an unmarked commit
defaults to a **patch** bump (not minor), so a hotfix can't accidentally collide
with a mainline tag; use `[bump:minor]`/`[bump:major]` to override. (If a line
predates auto-creation, fork it manually: `git branch release/vX.Y vX.Y.0 &&
git push origin release/vX.Y`.)

### Flavored variants

A **flavor** is an opt-in variant of an existing release, tagged
`vX.Y.Z-<flavor>` (e.g. `v0.6.0-asan`). Run the workflow manually from the
Actions tab with the **`flavor`** input set: it pins to the latest clean
release reachable, appends the suffix, and publishes a separate (prerelease)
release **without bumping the version line**. Flavored tags are unordered — the
version computation matches only clean `vX.Y[.Z]` tags, so a flavor never
becomes a baseline or shifts mainline. Consumers stay on clean versions by
default and opt in by pinning `TOOLCHAIN_VERSION=X.Y.Z-<flavor>`.

(The suffix is a label only — producing genuinely different binaries for a
flavor, e.g. via extra build-args, is wired up per flavor when defined.)

To avoid burning an hour rebuilding clang on every push, the workflow only
rebuilds a from-source tool when its inputs changed: a `detect` step
fingerprints each tool's Dockerfile plus the version vars it consumes against
the previous release, and reuses that release's binary for anything unchanged
(so editing only `Dockerfile.git` rebuilds just git). To force a full
from-source rebuild, run the workflow manually from the Actions tab with the
**`rebuild_all`** box ticked.

Build a single tool locally:

```sh
build/build-clang.sh arm64        # or amd64; also build-make.sh / build-git.sh / build-qemu.sh
build/fetch-bpftool.sh            # prebuilt; also fetch-veristat.sh / fetch-lvh.sh / fetch-esbuild.sh / fetch-libbpf-headers.sh
```
