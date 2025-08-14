#!/bin/bash

# rm-node-modules - find and delete node_modules directories (top-down)
# --------------------------------------------------------------
# A small utility to reclaim disk space and reset dependencies by
# recursively deleting node_modules folders under a given root directory.
#
# Defaults to current directory if no root is provided.

set -euo pipefail

SCRIPT_NAME="rm-node-modules"

usage() {
  cat <<'EOF'
rm-node-modules - find and delete node_modules directories (top-down)

Usage:
  rm-node-modules [options] [root]

Options:
  -y, --yes                 Proceed without interactive confirmation
      --dry-run             Show what would be removed and sizes; make no changes
      --debug               Print additional debug output
  -h, --help                Show help

Notes:
- Deletion order is top-down to ensure parent node_modules are removed first.
- Size estimation uses du -sk and is approximate.
EOF
}

debug=false
assume_yes=false
dry_run=false

log_debug() { if [ "$debug" = true ]; then echo "[debug] $*" >&2; fi }
log_err() { echo "[error] $*" >&2; }
log_info() { echo "$*"; }

# Parse args
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      assume_yes=true; shift;;
    --dry-run)
      dry_run=true; shift;;
    --debug)
      debug=true; shift;;
    -h|--help)
      usage; exit 0;;
    --)
      shift; while [[ $# -gt 0 ]]; do ARGS+=("$1"); shift; done; break;;
    -*)
      log_err "Unknown option: $1"; usage; exit 1;;
    *)
      ARGS+=("$1"); shift;;
  esac
done

root_dir="${ARGS[0]:-$(pwd)}"

if [ ! -d "$root_dir" ]; then
  log_err "Root directory not found: $root_dir"
  exit 1
fi

# Build find command (simple, no excludes/max-depth)

# Compose find that selects node_modules directories anywhere under root.
composed=( find "$root_dir" -type d -name node_modules -print )

log_debug "Find command: ${composed[*]}"

# Collect results into an array and sort by depth (ascending) to ensure top-down
nm_paths=()
while IFS= read -r line; do
  nm_paths+=("$line")
done < <("${composed[@]}" 2>/dev/null)

if [ ${#nm_paths[@]} -eq 0 ]; then
  log_info "No node_modules directories found under: $root_dir"
  exit 0
fi

depth_key() { awk -F"/" '{print NF"\t"$0}' | sort -n | cut -f2-; }

nm_paths_sorted=()
while IFS= read -r line; do
  nm_paths_sorted+=("$line")
done < <(printf '%s\n' "${nm_paths[@]}" | depth_key)

# Summarize
log_info "Found ${#nm_paths_sorted[@]} node_modules directories under: $root_dir"

# Compute total size up-front for confirmation
total_kb=0
for p in "${nm_paths_sorted[@]}"; do
  if [ -d "$p" ]; then
    sz=$(du -sk "$p" 2>/dev/null | awk '{print $1}')
    sz=${sz:-0}
    total_kb=$(( total_kb + sz ))
  fi
done

human_kb() {
  local kb="$1"
  if [ -z "$kb" ] || [ "$kb" -eq 0 ]; then echo "0K"; return; fi
  local bytes=$((kb * 1024))
  # Use awk for cross-platform human formatting
  awk -v b="$bytes" 'function human(x){
    s[0]="B";s[1]="K";s[2]="M";s[3]="G";s[4]="T";s[5]="P";
    if (x==0) return "0B"; i=int(log(x)/log(1024));
    return sprintf("%.1f%s", x/(1024^i), s[i])
  } BEGIN{print human(b)}'
}

if [ "$dry_run" = true ]; then
  log_info "--dry-run: showing what would be deleted"
  for p in "${nm_paths_sorted[@]}"; do
    kb=$(du -sk "$p" 2>/dev/null | awk '{print $1}')
    kb=${kb:-0}
    log_info "DRY: $p ($(human_kb "$kb"))"
  done
  log_info "Total: $(human_kb "$total_kb")"
  exit 0
fi

if [ "$assume_yes" = false ]; then
  log_info "About to delete ${#nm_paths_sorted[@]} node_modules directories. Total size: $(human_kb "$total_kb")."
  read -r -p "Proceed? [y/N] " rsp
  case "$rsp" in
    y|Y|yes|YES) ;;
    *) log_info "Aborted."; exit 0;;
  esac
fi

# Delete top-down
errors=0
for p in "${nm_paths_sorted[@]}"; do
  if [ -d "$p" ]; then
    log_info "Removing: $p"
    if rm -rf "$p" 2>/dev/null; then
      :
    else
      log_err "Failed to remove: $p"
      errors=$((errors+1))
    fi
  fi
done

if [ $errors -gt 0 ]; then
  log_err "Completed with $errors errors."
  exit 1
fi

log_info "Done."


