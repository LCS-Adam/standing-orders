#!/bin/bash
PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:${PATH:-}"; export PATH
set -uo pipefail

# sync-upstream.sh - clone or refresh every repository in config/upstream.conf
# into .upstream/<name>/, so a coding tool can read the author's own source
# instead of a copy this harness froze.
#
# usage:
#   scripts/sync-upstream.sh            clone or refresh everything
#   scripts/sync-upstream.sh --list     print the manifest, touch no network
#   scripts/sync-upstream.sh <name>...  just these entries
#
# exit: 0 all entries synced | 1 one or more failed | 2 usage or missing manifest
#
# The clones are SHALLOW and gitignored. They are read material, not a
# submodule and not part of the shipped set: `git ls-files --others
# --exclude-standard` skips them, so verify.sh never scans another project's
# code and `harness install` never ships it.
#
# WHY THIS IS NOT A SUBMODULE. A submodule pins a SHA and makes every clone of
# this repo drag the upstream down with it. The whole point here is to track
# what upstream ships and to leave the choice of when to refresh with the
# person running it.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${HARNESS_UPSTREAM_CONF:-$ROOT/config/upstream.conf}"
DEST="${HARNESS_UPSTREAM_DIR:-$ROOT/.upstream}"

die()  { printf 'sync-upstream: %s\n' "$1" >&2; exit "${2:-2}"; }
note() { printf 'sync-upstream: %s\n' "$1" >&2; }

command -v git >/dev/null 2>&1 || die "git not found"
[ -f "$CONF" ] || die "missing $CONF"

LIST=0; WANT=()
while [ $# -gt 0 ]; do
  case "$1" in
    --list) LIST=1 ;;
    -h|--help) sed -n '5,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) WANT+=("$1") ;;
  esac
  shift
done

# A name from the manifest becomes a path under $DEST and then an argument to
# `rm -rf`. `../production-cache` would reach outside .upstream/ and delete
# something real. Nothing downstream re-checks it, so it is checked once, here,
# and anything that is not a plain basename is refused rather than sanitised:
# a silently rewritten name would clone the right repo into the wrong place.
safe_name() { # safe_name <name>
  case "$1" in
    ''|.|..|*/*|*'\'*) return 1 ;;
    -*) return 1 ;;
  esac
  printf '%s' "$1" | grep -qE '^[A-Za-z0-9][A-Za-z0-9._-]*$'
}

wanted() {
  [ "${#WANT[@]}" -eq 0 ] && return 0
  local w; for w in "${WANT[@]}"; do [ "$w" = "$1" ] && return 0; done
  return 1
}

fail=0 seen=0
while read -r name url ref _rest; do
  case "${name:-}" in ''|\#*) continue ;; esac
  [ -n "${url:-}" ] && [ -n "${ref:-}" ] || { note "skipping malformed entry: $name"; fail=1; continue; }
  safe_name "$name" || { note "refusing unsafe entry name: $name"; fail=1; continue; }
  wanted "$name" || continue
  seen=$((seen+1))

  if [ "$LIST" -eq 1 ]; then
    printf '%-16s %s  (%s)\n' "$name" "$url" "$ref"
    continue
  fi

  target="$DEST/$name"
  if [ -d "$target/.git" ]; then
    # Refresh in place. reset --hard, not merge: this is a read-only mirror and
    # a local edit to it is a mistake, not work to preserve.
    git -C "$target" fetch --quiet --depth 1 origin "$ref" \
      && git -C "$target" reset --quiet --hard FETCH_HEAD \
      || { note "could not refresh $name from $url"; fail=1; continue; }
  else
    mkdir -p "$DEST"
    rm -rf "$target"
    git clone --quiet --depth 1 --branch "$ref" "$url" "$target" \
      || { note "could not clone $name from $url"; fail=1; continue; }
  fi
  printf '  %-16s %s @ %s\n' "$name" "$ref" "$(git -C "$target" rev-parse --short HEAD 2>/dev/null || echo unknown)"
done < "$CONF"

[ "$seen" -gt 0 ] || die "no matching entries in $CONF"
if [ "$fail" -ne 0 ]; then
  note "one or more entries failed; the harness still works, but the clones are stale or absent"
  exit 1
fi
exit 0
