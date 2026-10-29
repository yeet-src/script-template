# Build output styling — a checklist: one row per step with what it
# produced, then a summary row with the total time, and the artifacts:
#
#   ● toolchain  v0.10.1  ~/.local/share/yeet/toolchain/linux/x86_64/v0.10.1
#   ✔ vmlinux.h  src/bpf/include/vmlinux.h
#   ✔ cpusched   .build/bpf/cpusched.bpf.o
#   ✔ runqlat    .build/bpf/runqlat.bpf.o
#   ✔ link       dist/bin/probe.bpf.o
#   ✔ bundle     dist/index.js
#   ✔ done       myproject (0.66s)
#
#   ==> dist/bin/probe.bpf.o (8.1kb)
#   ==> dist/index.js (15.5kb)
#
# Rows go to stderr, so the build's stdout stays clean for piping. While a
# step runs, its row shows a spinner, then settles into the check. The
# commands themselves are hidden; `make V=1` echoes each one before its
# row. A failed step is marked ✘ in red after its own diagnostics, so a
# compiler error is never hidden. Color is used only when stderr is a
# terminal, TERM isn't dumb and NO_COLOR (https://no-color.org) is unset;
# the spinner needs the same, plus a serial build (parallel steps would
# fight over the line). The marks fall back to ASCII outside a UTF-8 locale.
#
# Included first by the project Makefile, so build/toolchain.mk and
# build/bpf.mk can use the macros below.

ifeq ($(V),1)
  Q :=
else
  Q := @
endif

COLOR := $(shell [ -t 2 ] && [ -z "$$NO_COLOR" ] && [ "$$TERM" != dumb ] && echo 1)
UTF8  := $(if $(findstring UTF-8,$(shell locale charmap 2>/dev/null)),1)
SPIN  := $(if $(and $(COLOR),$(if $(filter -j% --jobserver%,$(MAKEFLAGS)),,1)),1)

# Marks: done, pending/info, failed, warning; and the spinner frames.
ifeq ($(UTF8),1)
  M_OK := ✔
  M_ON := ●
  M_NO := ✘
  M_WN := ▲
  SPIN_FRAMES := ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
else
  M_OK := +
  M_ON := *
  M_NO := x
  M_WN := !
  SPIN_FRAMES := '\' '|' '/' '-'
endif

# Row formats take (tag, artifact, trailer); see `row`.
ifeq ($(COLOR),1)
  STEP_FMT   := \033[1;32m$(M_OK)\033[0m \033[1;36m%-10s\033[0m %s\n
  DONE_FMT   := \033[1;32m$(M_OK) %-10s\033[0m \033[1m%s\033[0m \033[1;32m(%s)\033[0m\n
  ART_FMT    := \033[1m==>\033[0m \033[35m%s\033[0m \033[1;32m(%s)\033[0m\n
  FAIL_FMT   := \033[1;31m$(M_NO)\033[0m \033[1;36m%-10s\033[0m %s \033[1;31m(%s)\033[0m\n
  SPIN_FMT   := \033[1;33m%s\033[0m \033[1;36m%-10s\033[0m %s
  STATUS_FMT := \033[1;34m$(M_ON)\033[0m \033[1;36m%-10s\033[0m %s\n
  WARN_FMT   := \033[1;33m$(M_WN)\033[0m %s\n
  ERROR_FMT  := \033[1;31m$(M_NO)\033[0m %s\n
else
  STEP_FMT   := $(M_OK) %-10s %s\n
  DONE_FMT   := $(M_OK) %-10s %s (%s)\n
  ART_FMT    := ==> %s (%s)\n
  FAIL_FMT   := $(M_NO) %-10s %s (%s)\n
  STATUS_FMT := $(M_ON) %-10s %s\n
  WARN_FMT   := $(M_WN) %s\n
  ERROR_FMT  := $(M_NO) %s\n
endif
# The shell scripts the build calls print the same way (fetch-toolchain.sh).
export STATUS_FMT WARN_FMT ERROR_FMT

# Elapsed time between $s and now as "0.21s", empty where date lacks %N.
elapsed = e=$$(date +%s%N 2>/dev/null); case "$$s$$e" in ""|*[!0-9]*) t="" ;; *) t=$$(awk "BEGIN { printf \"%.2fs\", ($$e - $$s) / 1e9 }") ;; esac

# $(call row,FMT,tag,artifact[,trailer]) — a shell fragment printing a row;
# a trailer (the total time, a size, or "failed") follows the artifact in
# parentheses where the format has a slot for it. The artifact and trailer
# are expanded by the shell, so they may hold a $$(…) substitution (see
# `filesize`).
row = printf '$(1)' $(if $(2),"$(2)" )"$(3)" $(if $(4),"$(4)" )>&2

# $(call step,tag,artifact,command) — run the command, then print its row;
# on failure print it as failed and stop. With the
# spinner, the command runs in the background with its output captured,
# the row animates until it exits, then the output (diagnostics) is
# replayed above the final row. Tag and artifact must not contain double
# quotes; a comma in the artifact needs $(comma).
define step
$(if $(filter 1,$(V)),$(info $(3)))@if [ -n "$(SPIN)" ]; then \
	out=$$(mktemp); ( $(3) ) >"$$out" 2>&1 & pid=$$!; \
	trap 'kill $$pid 2>/dev/null; printf "\r\033[2K" >&2' INT TERM; \
	set -- $(SPIN_FRAMES); n=$$#; i=0; \
	while kill -0 $$pid 2>/dev/null; do \
		eval "f=\$${$$((i % n + 1))}"; \
		printf '\r\033[2K$(SPIN_FMT)' "$$f" "$(1)" "$(2)" >&2; \
		i=$$((i + 1)); sleep 0.08; \
	done; \
	wait $$pid; rc=$$?; printf '\r\033[2K' >&2; cat "$$out" >&2; rm -f "$$out"; \
else ( $(3) ); rc=$$?; fi; \
if [ "$${rc:-1}" -eq 0 ]; then $(call row,$(STEP_FMT),$(1),$(2)); \
else $(call row,$(FAIL_FMT),$(1),$(2),failed); exit "$${rc:-1}"; fi
endef

# $(call done,artifact) — the summary row, timed from BUILD_START (set by
# the Makefile at parse time).
done = @s=$(BUILD_START); $(elapsed); $(call row,$(DONE_FMT),done,$(1),$$t); printf '\n' >&2

# $(call artifact,path) — a row listing a build output with its size, for
# the lines under the summary row: "==> path", no tag column.
artifact = @$(call row,$(ART_FMT),,$(1),$(call filesize,$(1)))

# $(call status,tag,message) — an informational row, no timing.
status = @printf '$(STATUS_FMT)' "$(1)" "$(2)" >&2
# $(call warn,message); $(call fail,message) is a shell fragment for
# `|| { $(call fail,…); }`.
warn = @printf '$(WARN_FMT)' "$(1)" >&2
fail = printf '$(ERROR_FMT)' "$(1)" >&2; exit 1

# $(call filesize,path) — a shell substitution yielding "15.5kb", for use
# inside a step's artifact text; "…" while the file doesn't exist yet (the
# spinner row is printed before the step has produced it).
comma := ,
filesize = $$(if [ -f $(1) ]; then wc -c < $(1) | awk '{ printf "%.1fkb"$(comma) $$1 / 1024 }'; else printf '$(if $(UTF8),…,...)'; fi)
