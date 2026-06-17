#!/usr/bin/env bash
# Scaffold a new yeet example project.
#
# Writes a starter directory laid out like the rest of `example/`:
#
#   <name>/
#     src/
#       bpf/<stem>.bpf.c   — minimal XDP noop with a ringbuf event
#       main.js            — loads the object, attaches the prog, drains events
#     bin/<slug>           — launcher: execs `yeet run ./src`
#     scripts/
#       common.sh          — POSIX sh helpers (sourced; no exec bit)
#       rolecall.sh        — POSIX sh; populates ROLECALL_RESULTS map
#                            takes optional names: `rolecall.sh os bash …`
#       install.sh         — dispatcher: sources rolecall, execs the
#                            right installer based on ROLECALL_RESULTS
#       installers/
#         macos.sh         — invoked when os=Darwin (bash)
#         macos/
#           Dockerfile     — built by macos.sh build_container()
#         linux.sh         — invoked when os=Linux (bash)
#     Makefile             — clang → build/<stem>.bpf.o, + rolecall/install
#     README.md            — build + run instructions
#     .gitignore           — /build/
#
# Run on the host (bash, no deps):
#
#   ./bootstrap.sh my-new-example
#   ./bootstrap.sh my-new-example --dest example
#   ./bootstrap.sh my-new-example --force
#
# Sources for the generated files live in ./template/ alongside this
# script. Placeholders __NAME__, __SLUG__, __STEM__, __OBJ_STEM__ are
# substituted in both file contents and path segments at scaffold time.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"

usage() {
  local code="${1:-0}"
  local msg="${2:-}"
  if [ -n "$msg" ]; then
    printf 'error: %s\n\n' "$msg" >&2
  fi
  cat >&2 <<EOF
usage: bootstrap.sh <name> [--dest <dir>] [--force]

  <name>         project directory name (kebab-case recommended)
  --dest <dir>   parent directory to scaffold into (default: cwd)
  --force, -f    overwrite existing files
EOF
  exit "$code"
}

project_name=""
dest="."
force=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage 0 ;;
    -f|--force) force=1; shift ;;
    -d|--dest)
      shift
      [ $# -gt 0 ] || usage 1 "--dest needs a path"
      dest="$1"
      shift
      ;;
    --) shift; break ;;
    -*) usage 1 "unknown flag: $1" ;;
    *)
      if [ -z "$project_name" ]; then
        project_name="$1"
      else
        usage 1 "unexpected positional: $1"
      fi
      shift
      ;;
  esac
done

[ -n "$project_name" ] || usage 1 "missing project name"
[ -d "$TEMPLATE_DIR" ] || { echo "error: template directory not found: $TEMPLATE_DIR" >&2; exit 1; }

name="$project_name"

# kebab-case slug: lowercase, [^a-z0-9]+ → '-', strip leading/trailing '-'
slug=$(printf '%s' "$name" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
[ -n "$slug" ] || slug="example"

# C identifier: '-' → '_', guard leading digit
stem=$(printf '%s' "$slug" | tr '-' '_')
case "$stem" in
  [0-9]*) stem="_$stem" ;;
esac

# libbpf truncates the data-section map names to the object stem's first 8 chars
obj_stem="${stem:0:8}"

target="$dest/$name"

if [ -d "$target" ] && [ "$force" -eq 0 ]; then
  if [ -n "$(ls -A "$target" 2>/dev/null || true)" ]; then
    echo "error: target $target exists and is not empty (pass --force to overwrite)" >&2
    exit 1
  fi
fi

mkdir -p "$target"

wrote_any=0
while IFS= read -r -d '' src; do
  rel="${src#"$TEMPLATE_DIR/"}"
  dst_rel=$(printf '%s' "$rel" \
    | sed -e "s|__SLUG__|$slug|g" -e "s|__STEM__|$stem|g")
  dst="$target/$dst_rel"

  if [ -e "$dst" ] && [ "$force" -eq 0 ]; then
    echo "error: refusing to overwrite $dst (pass --force)" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$dst")"
  sed \
    -e "s|__OBJ_STEM__|$obj_stem|g" \
    -e "s|__STEM__|$stem|g" \
    -e "s|__SLUG__|$slug|g" \
    -e "s|__NAME__|$name|g" \
    "$src" > "$dst"

  # Mirror the template's own exec bit; the template's mode is the spec.
  if [ -x "$src" ]; then
    chmod 755 "$dst"
  else
    chmod 644 "$dst"
  fi

  echo "  wrote $dst"
  wrote_any=1
done < <(find "$TEMPLATE_DIR" -type f -print0)

[ "$wrote_any" -eq 1 ] || { echo "error: no template files in $TEMPLATE_DIR" >&2; exit 1; }

echo ""
echo "Scaffolded $name at $target"
echo ""
echo "Next steps:"
echo "  cd $target"
echo "  make                 # build build/$stem.bpf.o (run inside Lima on macOS)"
echo "  ./bin/$slug          # or: ./src/main.js, or: yeet run ./src"
