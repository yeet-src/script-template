# v/ — vendored static build toolchain

Self-contained, statically-linked binaries of the tools a yeet script's BPF
build needs, so `make` works on any Linux host without a system clang or
bpftool installed. One subdirectory per architecture, named to match
`uname -m`:

```
v/
  x86_64/   make  clang  bpftool  esbuild     # per-arch static binaries
  aarch64/  make  clang  bpftool  esbuild
  include/  bpf/*.h                           # arch-independent libbpf SDK headers
  build/    build recipe + version pins (below)
```

The binaries are **fully static** (no shared-library dependencies), so they
run on any glibc or musl Linux of the matching arch.

| item              | what the build uses it for                              | source |
|-------------------|---------------------------------------------------------|--------|
| `make`            | drive the build. Bootstrapped by `yeet build` (it can't fetch itself) | built from GNU make source, musl-static |
| `clang`           | compile `src/bpf/*.bpf.c` (`-target bpf`)               | built from LLVM source, musl-static |
| `bpftool`         | generate `vmlinux.h` (BTF dump) and link BPF objects (`gen object`) | official static release, [libbpf/bpftool] |
| `esbuild`         | bundle the JS entry (`src/main.jsx` → `src/index.jsx`)  | official static (Go) binary, [@esbuild/*] |
| `include/bpf/*.h` | libbpf program headers a `.bpf.c` includes (`<bpf/bpf_helpers.h>`, …) | libbpf bundled with bpftool |

The libbpf headers are **SDK-level, not application source** — they are tied
to the bpftool/libbpf version and shared across arches, so they live with the
toolchain (added to the compile via `-I`), not committed into each project's
`src/`. A `.bpf.c` keeps including them with the usual `<bpf/…>` spelling.

`esbuild` is a self-contained Go binary, so the JS bundle step can run it
directly — no `npm install` of the platform package required. (`npm` itself,
for resolving the project's own dependencies, is still a host tool.)

## Using the vendored toolchain

A project's `build/toolchain.mk` resolves clang/bpftool/esbuild (and the
`include/` headers) automatically, in order: this in-repo `v/` tree → a shared
per-machine cache keyed by the pinned version → `$PATH`. See that file and
`build/fetch-toolchain.sh` for the cache mechanism. To point at the tools
explicitly:

```sh
make CLANG=…/v/$(uname -m)/clang BPFTOOL=…/v/$(uname -m)/bpftool \
     BPF_SYSINCLUDE=…/v/include
```

## Rebuilding / updating

Versions are pinned in [`build/versions.env`](build/versions.env). Bump them
there, then regenerate.

**bpftool**, **esbuild** and the **libbpf headers** (prebuilt, instant):

```sh
v/build/fetch-bpftool.sh         # both arches
v/build/fetch-esbuild.sh         # both arches
v/build/fetch-libbpf-headers.sh  # into v/include/bpf (matches bpftool version)
```

**make** (compiled from source, but tiny — seconds per arch, even emulated):

```sh
v/build/build-make.sh arm64      # or: amd64
```

**clang** (compiled from source). Build per-arch on a **native** machine — an
emulated x86_64 LLVM build on an arm64 host takes many hours:

```sh
v/build/build-clang.sh arm64     # or: amd64
```

The easiest path for both arches is CI: the
[`vendor-toolchain`](../.github/workflows/vendor.yml) workflow builds clang on
native x86_64 and arm64 runners, fetches bpftool, and commits the result back
into `v/`. Run it from the Actions tab (`workflow_dispatch`) or by changing
anything under `v/build/`.

The clang build (see [`build/Dockerfile.clang`](build/Dockerfile.clang))
compiles only LLVM's BPF backend and links libc/libstdc++/libgcc statically;
every optional LLVM dependency (zlib, zstd, libxml2, terminfo, libedit) is
disabled so nothing dynamic survives the link. The build self-tests that the
result has no `PT_INTERP` and can emit a BPF object before it is published.

[libbpf/bpftool]: https://github.com/libbpf/bpftool/releases
