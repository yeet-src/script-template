# test

Scaffolded by `example/bootstrap`. Replace this header with a real
description of what the example demonstrates.

```
src/bpf/test.bpf.c   # XDP noop with a ringbuf event + .bss counter
src/main.js              # loads the object, attaches, drains events
bin/test             # launcher: execs `yeet run ./src`
scripts/
  common.sh              # POSIX sh helpers (sourced; no exec bit)
                         #   - log / die / cprintf "%[red]…%[/]" [args]
  rolecall.sh            # POSIX sh; populates ROLECALL_RESULTS map
                         #   default suite, or `rolecall.sh os bash …`
  install.sh             # dispatches to installers/<os>.sh via rolecall
  installers/
    macos.sh             # higher-level installer (os=Darwin, bash)
    macos/
      Dockerfile         # built by macos.sh build_container()
      env.sh             # generated: CLANG/BPFTOOL via docker run
    linux.sh             # higher-level installer (os=Linux, bash)
    linux/
      env.sh             # generated: CLANG/BPFTOOL native on PATH
build/                   # generated; .gitignored
Makefile                 # clang → build/test.bpf.o, + rolecall/install
```

The starter wires an XDP noop that:

- Counts every packet into a `__u64` in `.bss` (`packets_seen`).
- Emits a small ringbuf event per packet up to an `event_budget`
  threshold pulled from `.rodata`.

## Build

```sh
make                     # writes build/test.bpf.o
```

On macOS, run `make` inside the Lima VM:

```sh
lima/scripts/vm_shell.sh yeet.debian-13 make
```

## Run

From the project root (any of these works):

```sh
./bin/test           # launcher
./src/main.js            # main.js shebang resolves to yeet
yeet run ./src
```

## Helpers

```sh
make rolecall            # runs scripts/rolecall.sh (env detection)
make install             # dispatches to scripts/installers/<os>.sh
```
