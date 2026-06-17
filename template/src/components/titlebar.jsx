// Status rail: brand, total switch rate across all CPUs, and the live
// min-slice knob value (what +/- patches into the kernel).
import { Layer, Text, bg, bold, fg, idx } from "yeet:tui";
import { fmtDuration, fmtRate } from "@/lib/format.js";

const RAIL = idx(235);
const SHEET = " ".repeat(600);

export default ({ cpus, minSlice }) => (
  <Layer height="1">
    <Text>{bg(RAIL)(SHEET)}</Text>
    <Text break="none">
      {() => {
        const total = cpus.get().reduce((s, c) => s + c.rate, 0);
        const sep = bg(RAIL)(fg(idx(240))("  ▏  "));
        return bg(RAIL)([
          bold(fg(idx(214))(" ● cpusched ")), sep,
          bold(`${fmtRate(total)}`), fg(idx(245))(" switches/s"), sep,
          fg(idx(245))("min-slice ≥ "), bold(fmtDuration(minSlice.get() * 1000)), fg(idx(240))("  [ +/- ]"),
        ]);
      }}
    </Text>
  </Layer>
);
