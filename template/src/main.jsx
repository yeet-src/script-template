/* Starter yeet script: cpusched — a live context-switch heat grid.
 *
 * Each CPU is a cell whose brightness tracks how fast it's context-
 * switching; pick a CPU (arrows or click) to watch its prev → next task
 * feed. It's a compact tour of the project layout and of yeet's reactive
 * BPF, in both directions:
 *
 *   kernel → user : probes/cpusched.js builds `cpus` with from() over the
 *                   sched_switch ring buffer — a subscription as a signal.
 *   user → kernel : +/- calls setMinSlice(), which patches a global in the
 *                   running program's .data section (DataSec) so the kernel
 *                   re-filters which switches it emits — live.
 *
 * Layout: probes/ (BPF-aware) → components/ (pure UI) → lib/ (pure helpers),
 * imported through the `@/` source alias and composed here.
 *
 * To ship a pure-JS script, delete src/bpf/, bin/, and probes/cpusched.js.
 */
import { Box, Text, fg, idx, mount, signal } from "yeet:tui";
import { numCpus } from "@/probes/probe.js";
import { cpus, minSlice, setMinSlice } from "@/probes/cpusched.js";
import { latency } from "@/probes/runqlat.js";
import TitleBar from "@/components/titlebar.jsx";
import Heatmap from "@/components/heatmap.jsx";
import Detail from "@/components/detail.jsx";
import Histogram from "@/components/histogram.jsx";
import Footer from "@/components/footer.jsx";

const SLICE_STEP = 100; // µs per +/- press
const HEAT_TOP = 2; // screen row of the first CPU row (title + heatmap header)

const selected = signal(0);
const move = (d) => selected.set(Math.max(0, Math.min(numCpus - 1, selected.get() + d)));

// Detail feed length = whatever's left under the heatmap (one row per CPU).
const detailRows = () => Math.max(3, tty.size().rows - numCpus - 5);

tty.on("keydown", (e) => {
  const code = e.code;
  const k = (e.key ?? "").toLowerCase();
  if (code === "Escape" || k === "q") return yeet.exit();
  if (code === "ArrowUp" || code === "ArrowLeft" || k === "k" || k === "h") move(-1);
  else if (code === "ArrowDown" || code === "ArrowRight" || k === "j" || k === "l") move(1);
  else if (k === "+" || k === "=") setMinSlice(minSlice.get() + SLICE_STEP);
  else if (k === "-" || k === "_") setMinSlice(minSlice.get() - SLICE_STEP);
});

// Cores are rows, so a click maps straight to its row. Keyboard is the
// robust path; this is best-effort geometry tracking the layout above.
tty.on?.("mousedown", (e) => {
  if (e.button !== 0) return;
  const i = e.clientY - HEAT_TOP;
  if (i >= 0 && i < numCpus) selected.set(i);
});

const Rule = () => <Text height="1">{fg(idx(238))("─".repeat(400))}</Text>;

const Root = () => (
  <Box>
    <TitleBar cpus={cpus} minSlice={minSlice} />
    <Heatmap cpus={cpus} selected={selected} />
    <Rule />
    <Box height="1fr" direction="row">
      <Box width="1fr">
        <Detail cpus={cpus} selected={selected} rows={detailRows} />
      </Box>
      <Box width="34">
        <Histogram latency={latency} />
      </Box>
    </Box>
    <Footer />
  </Box>
);

mount(Root);
await new Promise(() => {}); // keep the script alive; the TUI owns the screen
