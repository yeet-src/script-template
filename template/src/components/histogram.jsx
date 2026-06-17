// Run-queue latency as a log2 histogram. Reads the polled `latency` signal
// (cumulative counts per bucket) and draws a bar per bucket, the label
// being the bucket's lower bound.
import { Box, Text, fg, idx } from "yeet:tui";
import { fmtDuration, lpad } from "@/lib/format.js";

const LO = 8; // 2^8 ns = 256ns
const HI = 23; // 2^23 ns ≈ 8.4ms
const BARW = 16;

export default ({ latency }) => (
  <Box>
    <Text height="1">{fg(idx(244))(" runqueue latency  (wakeup → on-cpu)")}</Text>
    <Box>
      {() => {
        const slots = latency.get();
        let peak = 1;
        for (let i = LO; i <= HI; i++) if (slots[i] > peak) peak = slots[i];
        const rows = [];
        for (let i = LO; i <= HI; i++) {
          const n = slots[i] || 0;
          const w = Math.round((n / peak) * BARW);
          rows.push(
            <Text height="1" break="none">
              {[
                fg(idx(244))(`${lpad(fmtDuration(2 ** i), 7)} `),
                fg(idx(75))("█".repeat(w)),
                fg(idx(240))(n ? ` ${n}` : ""),
              ]}
            </Text>,
          );
        }
        return rows;
      }}
    </Box>
  </Box>
);
