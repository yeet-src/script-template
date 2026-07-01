#!/bin/sh
# Styled status lines for the build — one tidy, colored line per step, so a
# normal `yeet build` reads as a clean progress list instead of a dump of raw
# compiler commands. The build fragments call this (as `$(SAY)`) for every
# step; the raw tool commands are hidden unless `make V=1`.
#
# Color + glyphs engage only on a terminal with NO_COLOR unset. Piped or CI
# logs fall back to plain ASCII markers, so nothing here corrupts a log file.
#
#   pretty.sh head <title...>       rule + title            (build start)
#   pretty.sh step <tag> <msg...>   ▸ tag   msg             (a build step)
#   pretty.sh info <msg...>         ·  msg                  (dim note)
#   pretty.sh done <msg...>         ✔ msg + rule            (build finished)
set -eu

kind=${1:-}
[ $# -gt 0 ] && shift

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	B=$(printf '\033[1m')          # bold
	D=$(printf '\033[2m')          # dim
	R=$(printf '\033[0m')          # reset
	C=$(printf '\033[36m')         # cyan  — step tags
	G=$(printf '\033[32m')         # green — success
	arrow='▸'; bullet='●'; dot='·'; check='✔'
	rule='────────────────────────────────────────────'
else
	B=; D=; R=; C=; G=
	arrow='>'; bullet='*'; dot='-'; check='✓'
	rule='--------------------------------------------'
fi

case "$kind" in
	head)
		printf '\n%s%s %s%s\n%s%s%s%s\n' \
			"$B$C" "$bullet" "$*" "$R" "$D" "$rule" "$R" ""
		;;
	step)
		tag=${1:-}
		[ $# -gt 0 ] && shift
		printf '  %s%s%s %s%-6s%s %s\n' "$B" "$arrow" "$R" "$C" "$tag" "$R" "$*"
		;;
	info)
		printf '  %s%s%s %s%s%s\n' "$D" "$dot" "$R" "$D" "$*" "$R"
		;;
	done)
		printf '%s%s%s %s%s%s\n%s%s%s\n\n' \
			"$B$G" "$check" "$R" "$B" "$*" "$R" "$D" "$rule" "$R"
		;;
	*)
		printf '%s\n' "$*"
		;;
esac
