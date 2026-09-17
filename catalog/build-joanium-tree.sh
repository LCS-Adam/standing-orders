#!/bin/bash
PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:${PATH:-}"; export PATH
set -uo pipefail

# build-joanium-tree.sh - materialise the Joanium corpus into the two-level
# structure recorded in catalog/joanium-assignment.tsv.
#
#   catalog/build-joanium-tree.sh [dest]
#
# Default dest: .upstream/joanium-organized  (gitignored, like the clone it reads)
#
# WHY THE OUTPUT IS NOT COMMITTED. The corpus is 42 MB of someone else's
# Apache-2.0 work. What this repo carries is the taxonomy and the assignment,
# which are small and reviewable; the tree is regenerated from those plus the
# clone. Same split as plugins/: the recipe is versioned, the output is not.
#
# Each skill becomes <level1>/<level2>/<name>/SKILL.md, converted to this repo's
# skill contract: a directory whose name matches the frontmatter `name:`.
# Upstream ships flat files whose display name has spaces, which is why the
# ordinary installer refuses them (bin/harness, safe_component).
#
# CEILING, stated: this tree is for BROWSING. Claude Code discovers skills at
# skills/<name>/SKILL.md with no category nesting, so nothing here is invocable
# where it sits. Copy a leaf directory into ~/.claude/skills/ to use one.
# Installing all of them would be absurd and would swamp every session.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${JOANIUM_SRC:-$ROOT/.upstream/joanium-skills/Joanium}"
MAP="$ROOT/catalog/joanium-assignment.tsv"
DEST="${1:-$ROOT/.upstream/joanium-organized}"

die() { printf 'build-joanium-tree: %s\n' "$1" >&2; exit 1; }

[ -d "$SRC" ] || die "corpus not found at $SRC - run: harness upstream"
[ -f "$MAP" ] || die "missing $MAP"
command -v perl >/dev/null 2>&1 || die "perl not found"

case "$DEST" in
  */joanium-organized) [ ! -e "$DEST" ] || rm -rf "$DEST" ;;
  *) die "refusing to remove an unexpected path: $DEST" ;;
esac
mkdir -p "$DEST" || die "could not create $DEST"

# Slug collisions are REAL and were found the hard way: Data-Visualization.md and
# DataVisualization.md are two different upstream files that slug identically, so
# the second silently overwrote the first and the tree came out one short. A
# silent overwrite in a build is the worst outcome available, so the colliding
# paths are computed first and the later arrival gets a deterministic suffix.
declare -a COLLIDE=()
seen_tmp="$(mktemp)" || die "mktemp failed"
trap 'rm -f "$seen_tmp"' EXIT
while IFS=$'\t' read -r file l1 l2; do
  [ -n "${file:-}" ] || continue
  sl="$(printf '%s' "${file%.md}" \
        | perl -pe 's/([a-z0-9])([A-Z])/$1-$2/g; s/([A-Z]+)([A-Z][a-z])/$1-$2/g' \
        | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' | sed 's/^-*//; s/-*$//')"
  printf '%s/%s/%s\n' "$l1" "$l2" "$sl"
done < "$MAP" | sort | uniq -d > "$seen_tmp"
if [ -s "$seen_tmp" ]; then
  printf 'slug collisions, disambiguated with a numeric suffix:\n' >&2
  sed 's/^/  /' "$seen_tmp" >&2
fi

n=0; miss=0
while IFS=$'\t' read -r file l1 l2; do
  [ -n "${file:-}" ] || continue
  [ -f "$SRC/$file" ] || { printf '  missing from corpus: %s\n' "$file" >&2; miss=$((miss+1)); continue; }
  # Directory name from the FILENAME, not the display name: the display name has
  # spaces and ampersands. Strip .md, split PascalCase, lowercase, hyphenate.
  slug="$(printf '%s' "${file%.md}" \
          | perl -pe 's/([a-z0-9])([A-Z])/$1-$2/g; s/([A-Z]+)([A-Z][a-z])/$1-$2/g' \
          | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' | sed 's/^-*//; s/-*$//')"
  [ -n "$slug" ] || { printf '  unusable name: %s\n' "$file" >&2; miss=$((miss+1)); continue; }
  d="$DEST/$l1/$l2/$slug"
  # If this path is one of the known collisions and is already taken, suffix it
  # rather than overwrite. Deterministic: the order of the assignment file.
  if [ -e "$d/SKILL.md" ]; then
    k=2
    while [ -e "$DEST/$l1/$l2/$slug-$k/SKILL.md" ]; do k=$((k+1)); done
    slug="$slug-$k"; d="$DEST/$l1/$l2/$slug"
    printf '  collision: %s -> %s\n' "$file" "$l1/$l2/$slug" >&2
  fi
  mkdir -p "$d"
  # Rewrite only the frontmatter `name:` so the directory and the skill agree.
  # Body byte-identical: it is the author's work, Apache-2.0.
  perl -0777 -pe "BEGIN{\$s='$slug'} s/\\A---\\n(.*?)^name:[^\\n]*\\n/---\\n\$1name: \$s\\n/sm" \
    "$SRC/$file" > "$d/SKILL.md" || die "could not convert $file"
  n=$((n+1))
done < "$MAP"

# The guide goes IN the tree, because that is where someone browsing will be,
# not in catalog/ where they would have to already know to look. It is versioned
# in catalog/ and copied here, so a rebuild refreshes it rather than losing it.
cp "$ROOT/catalog/HOW-TO-USE-THESE-SKILLS.md" "$DEST/HOW-TO-USE-THESE-SKILLS.md" \
  || die "could not place the usage guide"
cp "$ROOT/catalog/joanium-taxonomy.md" "$DEST/TAXONOMY.md" \
  || die "could not place the taxonomy"

want=$(grep -c . "$MAP")
printf 'built %s skills under %s\n' "$n" "$DEST"
printf 'start at %s/HOW-TO-USE-THESE-SKILLS.md\n' "$DEST"
got=$(find "$DEST" -name SKILL.md | wc -l | tr -d ' ')
[ "$got" -eq "$n" ] || die "wrote $n but only $got SKILL.md exist - something was overwritten"
[ "$n" -eq "$want" ] || die "assignment has $want rows but only $n were built"
[ "$miss" -eq 0 ] || { printf '%s could not be placed\n' "$miss" >&2; exit 1; }
