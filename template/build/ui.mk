# Build output styling — cargo-like status lines:
#
#      Toolchain yeet v0.10.1 (~/.local/share/yeet/toolchain/linux/x86_64/v0.10.1)
#     Generating src/bpf/include/vmlinux.h
#      Compiling cpusched.bpf.c
#      Compiling runqlat.bpf.c
#        Linking bin/probe.bpf.o
#       Bundling src/main.jsx -> dist/index.jsx (15.5kb)
#       Finished build in 0.84s
#
# A bold green verb, right-aligned to 12 columns, then the message — on
# stderr, like cargo, so the build's stdout stays clean for piping. The
# commands themselves are hidden; `make V=1` echoes each one under its status
# line. Color is used only when stderr is a terminal, TERM isn't dumb and
# NO_COLOR (https://no-color.org) is unset. Compiler diagnostics pass through
# untouched, so a warning or error is never hidden.
#
# Included first by the project Makefile, so build/toolchain.mk and
# build/bpf.mk can use `$(Q)` and `$(call status,Verb,message)`.

ifeq ($(V),1)
  Q :=
else
  Q := @
endif

COLOR := $(shell [ -t 2 ] && [ -z "$$NO_COLOR" ] && [ "$$TERM" != dumb ] && echo 1)
ifeq ($(COLOR),1)
  STATUS_FMT := \033[1;32m%12s\033[0m %s\n
  WARN_FMT   := \033[1;33mwarning\033[0m: %s\n
  ERROR_FMT  := \033[1;31merror\033[0m: %s\n
else
  STATUS_FMT := %12s %s\n
  WARN_FMT   := warning: %s\n
  ERROR_FMT  := error: %s\n
endif
# The shell scripts the build calls print the same way (fetch-toolchain.sh).
export STATUS_FMT WARN_FMT ERROR_FMT

# $(call status,Verb,message) and $(call warn,message) are whole recipe lines;
# $(call fail,message) is a shell fragment for `|| { $(call fail,…); }`.
# Messages must not contain single quotes.
status = @printf '$(STATUS_FMT)' '$(1)' '$(2)' >&2
warn   = @printf '$(WARN_FMT)' '$(1)' >&2
fail   = printf '$(ERROR_FMT)' '$(1)' >&2; exit 1
