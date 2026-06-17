// BPF data layer — the only BPF-aware module. It loads the program,
// subscribes to the context-switch ring buffer, and exposes plain reactive
// signals; it also owns the runtime knob the UI patches into the kernel.
//
// Two directions of reactivity live here:
//   kernel -> user : `cpus` is built with from() over the ring buffer — the
//                    subscription's lifecycle is tied to the signal being
//                    watched, and a window timer turns events into per-CPU
//                    rates + a rolling feed.
//   user -> kernel : setMinSlice() patches the `min_slice_ns` global in the
//                    program's .data section, so the kernel re-filters live.
import { DataSec, RingBuf } from "yeet:bpf";
import { from, signal } from "yeet:tui";
import { _ } from "yeet:helpers";
import { control, numCpus } from "@/probes/probe.js";

const WINDOW_MS = 500; // rate window
const FEED = 64; // recent switches kept per CPU
const TIME_COLS = 50; // history columns in the heatmap (~25s at 500ms)

const events = new RingBuf(control, "events");
const knobs = new DataSec(control, "probe.data");

const commStr = (c) => {
  if (typeof c === "string") return c.replace(/\0.*$/s, "");
  if (!c) return "";
  let s = "";
  for (const b of c) { if (b === 0) break; s += String.fromCharCode(b); }
  return s;
};

// Per-CPU state: [{ rate, recent: [{prev, next, slice}] }]. One ring-buffer
// subscription feeds every CPU; the window timer publishes a snapshot. The
// subscription is set up when the signal is first watched and torn down when
// it isn't — that's what from() gives us.
const blankCpu = () => ({ rate: 0, recent: [], hist: new Array(TIME_COLS).fill(0) });

export const cpus = from((state) => {
  const acc = Array.from({ length: numCpus }, blankCpu);
  const sub = events.subscribe((w) => {
    const e = w?.sched_event ?? w;
    const c = e && acc[e.cpu];
    if (!c) return;
    c.count = (c.count || 0) + 1;
    c.recent.unshift({ prev: commStr(e.prev_comm), next: commStr(e.next_comm), slice: Number(e.slice_ns) });
    if (c.recent.length > FEED) c.recent.pop();
  });
  const secs = WINDOW_MS / 1000;
  const h = setInterval(() => {
    state.set(acc.map((c) => {
      const rate = (c.count || 0) / secs;
      c.count = 0;
      c.hist.push(rate); // scroll the per-CPU history one column
      c.hist.shift();
      return { rate, recent: c.recent.slice(), hist: c.hist.slice() };
    }));
  }, WINDOW_MS);
  return () => { clearInterval(h); sub.then(_.unsubscribe()); };
}, Array.from({ length: numCpus }, blankCpu));

// The runtime knob, in microseconds for the UI. Initial value MUST match
// the program's compiled default (1ms) so the display matches the kernel
// before the first patch. Writing it patches the kernel-side global live.
export const minSlice = signal(1000);

export function setMinSlice(us) {
  us = Math.max(0, us);
  minSlice.set(us);
  // min_slice_ns is __u64 — DataSec.patch wants a BigInt for 64-bit fields.
  knobs.patch({ min_slice_ns: BigInt(us * 1000) });
}
