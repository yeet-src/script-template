// A real heatmap: one row per CPU, one column per time sample (newest on
// the right). Each cell's background is the core's switch rate at that
// instant, scaled against the global peak so hot cores read brighter than
// quiet ones. Reads `cpus` (each entry carries a `hist` ring) + `selected`.
import { Box, Text, bold, fg, idx } from "yeet:tui";
import { heat } from "@/lib/format.js";

export default ({ cpus, selected }) => (
  <Box>
    <Text height="1">
      {fg(idx(244))("  cores × time   (newest → right)   brightness = switch rate")}
    </Text>
    <Box>
      {() => {
        const list = cpus.get();
        const sel = selected.get();
        let peak = 1;
        for (const c of list) for (const v of c.hist) if (v > peak) peak = v;
        return list.map((c, i) => {
          const on = i === sel;
          const label = `${on ? "▸" : " "} cpu ${String(i).padStart(2)} `;
          const cells = c.hist.map((v) => fg(heat(v / peak))("█"));
          return (
            <Text height="1" break="none">
              {[on ? bold(fg(idx(231))(label)) : fg(idx(245))(label), ...cells]}
            </Text>
          );
        });
      }}
    </Box>
  </Box>
);
