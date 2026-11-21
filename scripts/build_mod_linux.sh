#!/usr/bin/env bash
# Linux port of mod-src/scripts/build_mod.ps1 (pack step only; runtime check is separate).
# Usage: build_mod_linux.sh <mod-src dir> <gdre_tools.x86_64> <output dir>
set -euo pipefail
SRC_REPO=$(realpath "$1"); GDRE=$(realpath "$2"); OUT=$(realpath -m "$3")
PROJECT="$SRC_REPO/mod/overrides"
mkdir -p "$OUT"
BUILD=$(mktemp -d "$OUT/.build-XXXXXX")
trap 'rm -rf "$BUILD"' EXIT
SOURCE="$BUILD/source"; mkdir -p "$SOURCE"

# Copy sources, minus project files (same exclusions as the author's builder).
for entry in "$PROJECT"/* "$PROJECT"/.[!.]*; do
  [ -e "$entry" ] || continue
  case "$(basename "$entry")" in .godot|.git|project.godot|export_presets.cfg) continue;; esac
  if find "$entry" -type l | grep -q .; then echo "Links not supported in $entry" >&2; exit 1; fi
  cp -r "$entry" "$SOURCE/"
done
mkdir -p "$SOURCE/.godot"
cp -r "$PROJECT/.godot/imported" "$SOURCE/.godot/"

# Reject missing or stale imports.
while IFS= read -r -d '' imp; do
  dest=$(grep -m1 -oP '^path="res://\K\.godot/imported/[^"]+' "$imp" || true)
  [ -n "$dest" ] || continue
  asset=${imp%.import}
  md5f="$SOURCE/${dest%.*}.md5"
  [ -f "$SOURCE/$dest" ] && [ -f "$md5f" ] || { echo "Missing mod import: $asset" >&2; exit 1; }
  h=$(md5sum "$asset" | cut -d' ' -f1)
  grep -qi "source_md5=\"$h\"" "$md5f" || { echo "Stale mod import: $asset" >&2; exit 1; }
done < <(find "$SOURCE" -name '*.import' -type f -print0)

# .remap beside each .gd so the engine prefers text scripts over shipped bytecode.
while IFS= read -r -d '' gd; do
  rel=${gd#"$SOURCE/"}
  printf '[remap]\npath="res://%s"\n' "$rel" > "$gd.remap"
done < <(find "$SOURCE" -name '*.gd' -type f -print0)

STAGE="$BUILD/lucid-blocks-coop.pck"
"$GDRE" --headless "--pck-create=$SOURCE" --pck-version=2 --pck-engine-version=4.6.0 "--output=$STAGE" > "$BUILD/pack.log" 2>&1
if grep -qiE 'SCRIPT ERROR:|ERROR:|Parse Error|Failed' "$BUILD/pack.log"; then cat "$BUILD/pack.log" >&2; exit 1; fi

# Header check: GDPC, pack v2, engine 4.6.
python3 -I -c 'import struct,sys; d=open(sys.argv[1],"rb").read(16); m,v,a,b=struct.unpack("<4I",d); sys.exit(0 if (m,v,a,b)==(0x43504447,2,4,6) else 1)' "$STAGE" \
  || { echo "Bad PCK header" >&2; exit 1; }
mv "$STAGE" "$OUT/lucid-blocks-coop.pck"
sha256sum "$OUT/lucid-blocks-coop.pck"
