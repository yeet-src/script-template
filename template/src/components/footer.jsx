// Key-hint rail.
import { Layer, Text, bg, fg, idx } from "yeet:tui";

const RAIL = idx(235);
const SHEET = " ".repeat(600);

export default () => (
  <Layer height="1">
    <Text>{bg(RAIL)(SHEET)}</Text>
    <Text break="none">
      {bg(RAIL)([
        fg(idx(245))(" ←/↑/→/↓ select CPU   +/- min-slice   q quit   "),
        fg(idx(240))("· +/- patches the kernel's filter live (DataSec) ·"),
      ])}
    </Text>
  </Layer>
);
