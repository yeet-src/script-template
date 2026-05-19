# bootstrap

Tiny Node.js scaffold for new yeet example projects. Writes a starter
directory that mirrors the layout used elsewhere under `example/`:

```
<name>/
  <stem>.bpf.c   — minimal XDP noop with a ringbuf event + .bss counter
  main.js        — loads the object, attaches the prog, drains events
  Makefile       — clang → <stem>.bpf.o, mirrors the rest of example/
  README.md      — build + run instructions
```

The generated `main.js` exercises the three most common surfaces:
`RingBuf` subscription, `DataSec` reads, and `attach`. Strip whatever
you don't need.

## Usage

```sh
node example/bootstrap/bootstrap.js <name> [--dest <dir>] [--force]
```

- `<name>` — project directory name. Normalized to a kebab-case slug
  for filenames and a C identifier for prog/struct symbols.
- `--dest <dir>` — parent directory (default: cwd). Pass `--dest example`
  to drop the new project next to the others.
- `--force` — overwrite existing files in the target directory.

### Examples

```sh
# Scaffold ./my-probe in the current directory.
node example/bootstrap/bootstrap.js my-probe

# Scaffold example/my-probe alongside the other built-in examples.
node example/bootstrap/bootstrap.js my-probe --dest example
```

After scaffolding, build the BPF object inside the Lima VM (macOS) or
directly (Linux):

```sh
cd example/my-probe
clang -O2 -g -target bpf -c my_probe.bpf.c -o my_probe.bpf.o
yeet run .
```

## Notes

- The script is plain Node ≥ 18, no dependencies, no install step.
- Templates are inline in `bootstrap.js` — edit them there if you want
  a different default shape (e.g. a `HashMap` starter instead of a
  ringbuf starter).
- The C identifier is derived from the slug (`my-probe` → `my_probe`),
  so the generated prog is `my_probe_count` and the ringbuf event
  struct is `my_probe_event`. Rename freely once scaffolded.
