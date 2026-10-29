# __NAME__

A yeet script: a reactive JSX TUI bundled with esbuild, a `#/` import root,
and a BPF program — all driven by one `make`.

The starter is **cpusched**: a live scheduler dashboard. The top is a
cores × time heatmap of context-switch rate (one row per CPU, newest column
on the right); pick a CPU (arrows or click) to watch its `prev → next` task
feed; and a log2 histogram tracks run-queue latency. It's a small but
complete tour of the layout and of yeet's reactive BPF.

## Reactive, both ways + both egress patterns

- **kernel → user, streamed** — `probes/cpusched.js` builds the `cpus`
  signal with `from(state => { …events.subscribe…; return cleanup })`: a
  ring-buffer subscription expressed as a reactive signal whose lifecycle is
  tied to the UI watching it. A window timer turns the stream into per-CPU
  rates, histories, and feeds.
- **kernel → user, polled** — `probes/runqlat.js` reads a histogram the
  kernel aggregates in an array map (`ArrayMap.lookup` on a timer) — the
  other egress pattern. Its program lives in a second `.bpf.c`.
- **user → kernel** — `+`/`-` call `setMinSlice()`, which `DataSec.patch()`es
  the `min_slice_ns` global in the *running* program's `.data` section. The
  kernel then only emits switches whose outgoing task ran that long — a filter
  you cannot do in userspace, since JS only sees events the kernel emitted.

## Two BPF programs, one object

`src/bpf/*.bpf.c` are independent units that `bpftool gen object` links into
one `dist/bin/probe.bpf.o`: `cpusched.bpf.c` (the sched_switch stream + the knob)
and `runqlat.bpf.c` (wakeup→on-CPU latency). Add another `.bpf.c` and it's
linked in automatically — keep `char LICENSE[]` in exactly one unit, and
give each program a unique name. `probes/probe.js` loads the object once and
shares its `control`; each probe module attaches its own maps.

## Layout

```
Makefile              build frontend — orchestrates the two compilers
build/bpf.mk          clang + bpftool rules: src/bpf/*.bpf.c -> dist/bin/probe.bpf.o
build/gen-vmlinux.sh  generates src/bpf/include/vmlinux.h from kernel BTF
package.json          project manifest + optional npm/jsr deps
tsconfig.json         `#/` -> ./src path alias (the bundle-time half of `#/`)
src/main.jsx          entry — composition root: input + mount
src/probes/probe.js   loads the shared BPF object (binds maps, start())
src/probes/cpusched.js  sched_switch stream → signals + the DataSec knob
src/probes/runqlat.js   polls the run-queue-latency histogram map
src/components/*.jsx   pure UI: titlebar, heatmap, detail, histogram, footer
src/lib/format.js     pure render helpers (rate, duration, heat color)
src/bpf/cpusched.bpf.c  sched_switch program + the runtime knob
src/bpf/runqlat.bpf.c   wakeup→on-CPU latency histogram
dist/                 build output: index.js + bin/probe.bpf.o — runs on its own (gitignored)
pkg/                  dist/ packed for shipping as <name>-<version>.tar.gz
                      (`make pkg`); unpack anywhere, `yeet run .` (gitignored)
.github/workflows/kernel-matrix.yml  CI: verify the object across kernels
build/verify-kernel.sh  the in-VM gate that workflow runs
```

The JS is layered: `probes/` is the only BPF-aware code (it owns the object
and exposes plain signals), `components/` is pure presentation that reads
those signals, and `lib/` is pure helpers. They reference each other through
the `#/` root; `main.jsx` wires them together and owns input.

## Build & run

```sh
make           # compile BPF + bundle JS into dist/
make V=1       # same, showing every command behind the status lines
make pkg       # also pack dist/ into pkg/<name>-<version>.tar.gz for shipping
yeet run .     # runs the bundled dist/index.js (needs root for BPF)
```

`make` runs two independent compilers: **clang + bpftool** compile
`src/bpf/*.bpf.c` and link them into one loadable object `dist/bin/probe.bpf.o`;
**esbuild** bundles `src/main.jsx` into `dist/index.js`, resolving `#/`
imports (and inlining any npm/jsr deps you add) and leaving `yeet:*` builtins
external. esbuild is vendored by the toolchain, so the build needs no
node/npm.

The data layer loads the object at runtime:

```js
import probe from "#/bin/probe.bpf.o";   // a BpfObject for that file
const control = await probe
  .bind("events", { kind: "ringbuf", btf_struct: "sched_event" })
  .bind("probe.data", { kind: "data" })   // the .data section that holds the knob
  .start();                                // the tracepoint auto-attaches
```

Importing a `.bpf.o` yields a `BpfObject` for it. `#/bin/` is the built-object
dir: `dist/bin/` in the tree, `./bin/` beside the bundle — see *the `#/` root*
below. `probe.data` is libbpf's
name for this object's `.data` section (confirm with
`bpftool btf dump file dist/bin/probe.bpf.o` if you rename things).

## Testing across kernels

Run `make veristat` to load `dist/bin/probe.bpf.o` with veristat on **your** kernel —
a quick check that every program passes the verifier, plus per-program
complexity (insns/states). It needs privileges to load programs, so use `sudo`.

A BPF program that loads on your laptop can be rejected by an older kernel's
verifier. `.github/workflows/kernel-matrix.yml` guards against that: for each
kernel in its matrix it builds `dist/bin/probe.bpf.o`, boots that kernel in a VM
([cilium's little-vm-helper](https://github.com/cilium/little-vm-helper), images
from `quay.io/lvh-images`), and runs the vendored static **veristat** against the
object — failing the job if the verifier rejects any program. The check is
`build/verify-kernel.sh`.

Edit `matrix.kernel` to the kernels you care about (tags at
[quay.io/lvh-images/kind](https://quay.io/repository/lvh-images/kind?tab=tags);
`<ver>-main` tracks the newest build of each line). A program using a feature
newer than a listed kernel will fail there by design — that failure *is* the
signal of your minimum kernel.

To run the same matrix **locally** (Linux + KVM), `make veristat-matrix` — it
boots those kernel images with [`lvh`](https://github.com/cilium/little-vm-helper)
+ QEMU and prints an `ok`/`FAIL` grid. Pick kernels with
`make veristat-matrix KERNELS="6.6-main bpf-next-main"`. Both `lvh` and a static
`qemu` are fetched on demand (VM infra, not part of the build toolchain) — the
vendored static qemu comes from the toolchain release, checksum-pinned in
`build/toolchain.lock`, falling back to a system `qemu-system` if absent.

> Requires a toolchain pin (`build/toolchain.lock`) that ships `veristat`; the
> workflow says so explicitly if the pinned version predates it.

`#/` is the one import root: `src/`. esbuild maps it there via tsconfig
`paths` at bundle time, and the runtime maps it there via the `imports` field
of `package.json` (Node-style subpath imports), so `#/lib/format.js` works
both bundled and standalone (`yeet run src/probes/probe.js`). `#/bin/` is the
one exception, the built-object dir, mapped to `dist/bin/`. The bundle doesn't
use `#/` at all: sources are inlined, and the external `#/bin/…` object imports
are rewritten by an esbuild alias to `./bin/…` — so a copied `dist/` runs by
itself with no manifest, and another object is just another import.

## npm / jsr packages

The starter needs no third-party packages — it imports only `yeet:*` builtins
and local `#/` modules, so `make` builds with no npm/node and no `node_modules`.

To pull in a dependency, add it to `package.json` and install it into
`node_modules` with whatever package manager you like (`npm`, `pnpm`, `bun`, …)
— esbuild inlines whatever it finds there at bundle time. Only packages that
run in bare V8 work: no Node builtins (`fs`, `net`, …), and no `Intl` /
`TextEncoder` / `TextDecoder`.

## Pure-JS scripts

Don't need BPF? Delete `src/bpf/`, `src/probes/probe.js`, and `src/probes/cpusched.js`, then
feed the components from any source that exposes the same signals.

## Prerequisites

- `clang` and `bpftool` (for the BPF leg; `bpftool` generates
  `src/bpf/include/vmlinux.h` from the host kernel, which needs `CONFIG_DEBUG_INFO_BTF`)

Both come from the static toolchain, resolved by `build/toolchain.mk`. With
the `yeet` CLI on PATH the build runs them as `yeet toolchain exec <tool>`
from the toolchain `yeet toolchain default` points at — one install shared
with the CLI, kept current with `yeet toolchain update`. If none is installed
yet, the first `make` installs the pinned version. Without `yeet`, the build
fetches the version pinned in `build/toolchain.lock` into a per-machine cache
(`~/.cache/yeet/toolchain/`) once; `make YEET=` forces that path even when
`yeet` is installed. `make clangd` writes a `.clangd` pointing at whichever
one resolved.

No node/npm is required: esbuild is vendored by the toolchain, and the starter
has no third-party deps. (You only need a package manager if you add npm/jsr
dependencies of your own — see *npm / jsr packages* above.)
