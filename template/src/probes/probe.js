// Shared BPF object. Both .bpf.c units are linked into one bin/probe.bpf.o
// and loaded once here; the per-feature probe modules (cpusched.js,
// runqlat.js) import this `control` and attach their own maps to it. All
// binds must happen before the single start(), so they live together here.
// `#/` resolves against the script root, so the import is stable regardless of
// where the loading module sits in the bundle.
import probe from "#/bin/probe.bpf.o";

export const control = await probe
  .bind("events", { kind: "ring_buf", btf_struct: "sched_event" }) // cpusched stream
  .bind("probe.data", { kind: "data" }) // cpusched min-slice knob (.data section)
  .bind("runq_hist", { kind: "array" }) // runqlat histogram (polled)
  .start(); // the tracepoints auto-attach

export const numCpus = system.numCpus;
