// Key-hint rail. Each shortcut is a raised key-cap — the key glyph in bold
// gold on a tile a shade lighter than the rail — followed by a dimmed label,
// so the keys pop out of the line and read at a glance.
import { Layer, Text, bg, bold, fg, idx } from "yeet:tui";

const RAIL = idx(235); // hint-rail background
const CAP = idx(238); // key-cap tile, a shade lighter than the rail
const GLYPH = idx(222); // bright gold key text
const LABEL = idx(247); // dimmed description
const SHEET = " ".repeat(600);

// A key-cap + its label: bold gold glyph on a raised tile, then a dim word.
const hint = (keys, label) => [
  bg(CAP)(bold(fg(GLYPH)(` ${keys} `))),
  fg(LABEL)(` ${label}   `),
];

export default () => (
  <Layer height="1">
    <Text>{bg(RAIL)(SHEET)}</Text>
    <Text break="none">
      {bg(RAIL)([
        "  ",
        ...hint("←/↑/→/↓", "select CPU"),
        ...hint("+/-", "min-slice"),
        ...hint("q", "quit"),
      ])}
    </Text>
  </Layer>
);
