// Shared BPF object. Both .bpf.c units are linked into one dist/bin/probe.bpf.o
// and loaded once here; the per-feature probe modules (cpusched.js,
// runqlat.js) import this `control` and attach their own maps to it. All
// binds must happen before the single start(), so they live together here.
// Importing a `.bpf.o` yields a BpfObject for that file (the loader's
// BpfObjectRule). `#/` is the src/ root, except `#/bin/`, the built-object
// dir: package.json maps it to dist/bin/, so this module also runs
// standalone, and in the bundle esbuild rewrites the prefix to ./bin/, so a
// copied dist/ runs on its own.
import probe from "#/bin/probe.bpf.o";

export const control = await probe
  .bind("events", { kind: "ringbuf", btf_struct: "sched_event" }) // cpusched stream
  .bind("probe.data", { kind: "data" }) // cpusched min-slice knob (.data section)
  .bind("runq_hist", { kind: "array" }) // runqlat histogram (polled)
  .start(); // the tracepoints auto-attach

export const numCpus = system.numCpus;
