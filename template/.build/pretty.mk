# Pretty build output, shared by the other build fragments.
#
# SAY renders a styled status line (see .build/pretty.sh). Q hides the raw tool
# command behind each step so a normal build shows tidy step lines instead of
# full clang/bpftool/esbuild invocations — run `make V=1` (or `yeet build V=1`)
# to see the exact commands. Errors always surface: only stdout on success is
# suppressed, never a tool's stderr.
SAY := sh .build/pretty.sh
Q   := $(if $(V),,@)

# Silence the vendored toolchain fetch's "toolchain ready" summary in a normal
# build (it prints on every build, warm cache included); `V=1` shows it, along
# with the raw commands. Exported so the fetch script sees it. Real "fetch …"
# download progress is never suppressed.
export YEET_TOOLCHAIN_QUIET := $(if $(V),,1)
