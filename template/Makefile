# Thin shim → the real build machinery under .build/.
#
# `yeet build` is the frontend for this script; the low-level orchestration
# (this project's two compilers — clang for BPF, esbuild for JS — plus the
# toolchain resolution and the kernel test harness) lives under .build/, which
# a generated project gitignores wholesale and `yeet build` materializes. This
# shim just forwards a bare `make` (and the `make` that `yeet run` invokes
# automatically) to .build/Makefile, keeping the project root as the working
# directory so every path inside resolves as written.
#
# Command-line variables (e.g. `make veristat-matrix KERNELS="6.6-main"`) and
# overrides (`make CLANG=…`) propagate to the sub-make automatically via
# MAKEFLAGS, so they need no plumbing here.

REAL := .build/Makefile

.DEFAULT_GOAL := all

all bpf bundle veristat veristat-matrix postgen clangd clean:
	@$(MAKE) --no-print-directory -f $(REAL) $@

.PHONY: all bpf bundle veristat veristat-matrix postgen clangd clean
