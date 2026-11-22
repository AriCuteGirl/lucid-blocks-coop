#!/usr/bin/env bash
# trials.sh <gdre> <game> <work> <only> <rounds> <timeout> label=pck|none ...   (all labels in parallel)
GDRE=$1; G=$2; W=$3; ONLY=$4; R=$5; T=$6; shift 6; HERE=$(dirname "$(realpath "$0")")
for spec in "$@"; do l=${spec%%=*}; p=${spec#*=}
  mkdir -p "$W/bin/$l"; printf '[application]\nrun/flush_stdout_on_print=true\n\n[debug]\nsettings/gdscript/always_track_call_stacks=true\n' > "$W/bin/$l/override.cfg"
  ( TIMEOUT=$T "$HERE/run_combat_probe.sh" "$l" "$G" "$p" "$GDRE" "$W" rounds="$R" only="$ONLY" > "$W/trial-$l.txt" 2>&1 ) &
done; wait
for spec in "$@"; do l=${spec%%=*}
  echo "$l $(grep -m1 exit= "$W/trial-$l.txt") fights=$(grep -c 'hit done' "$W/combat/$l/steps" 2>/dev/null) last=[$(tail -1 "$W/combat/$l/steps" | cut -d' ' -f2- | cut -c1-40)] $(grep -oE 'addr=[0-9A-F]+' "$W/trial-$l.txt" | head -1)"
done
