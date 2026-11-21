#!/usr/bin/env bash
# Runs steam_host_probe.gd in a disposable prefix with the owner's Steam online.
# Usage: run_steam_probe.sh <game dir> <mod pck> <gdre> <work dir> [invite] [windowed]
set -uo pipefail
GAME=$(realpath "$1"); PACK=$(realpath "$2"); GDRE=$(realpath "$3"); W=$(realpath -m "$4"); MODE="${5:-}"; VIEW="${6:-}"
HERE=$(dirname "$(realpath "$0")")
P="$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/proton"
RT="$W/bin/steam"; PFX="$W/prefix/steam"; OUT="$W/steamprobe-out"
export STEAM_COMPAT_DATA_PATH="$PFX" STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
"$P" run wineserver -k >/dev/null 2>&1
rm -rf "$W/steamprobe" "$OUT"; mkdir -p "$W/steamprobe/mods/steam_probe" "$RT" "$PFX" "$OUT"
cp "$HERE/steam_host_probe.gd" "$W/steamprobe/mods/steam_probe/mod_init.gd"
"$GDRE" --headless "--pck-create=$W/steamprobe" --pck-version=2 --pck-engine-version=4.6.0 "--output=$W/zz-steam-probe.pck" >/dev/null 2>&1
rm -rf "$RT/mods"; mkdir -p "$RT/mods"
for f in lucid-blocks.exe libgdblocks.windows.template_release.double.x86_64.dll libgodotsteam.windows.template_release.double.x86_64.dll steam_api64.dll; do ln -sfn "$GAME/$f" "$RT/$f"; done
cp "$PACK" "$W/zz-steam-probe.pck" "$RT/mods/"
L="$PFX/pfx/drive_c/users/steamuser/AppData/Roaming/lucid blocks/logs/godot.log"; rm -f "$L"
ARGS=(--headless); [ "$VIEW" = windowed ] && ARGS=(--windowed --resolution 960x540)
PRELOAD=""; [ "$VIEW" = windowed ] && PRELOAD="$HOME/.local/share/Steam/ubuntu12_32/gameoverlayrenderer.so:$HOME/.local/share/Steam/ubuntu12_64/gameoverlayrenderer.so"
( cd "$RT" && SteamAppId=3495730 SteamGameId=3495730 LD_PRELOAD="$PRELOAD" WINEDEBUG=-all \
    "$P" run "$RT/lucid-blocks.exe" "${ARGS[@]}" --max-fps 60 -- $MODE "beat=Z:$OUT/beat" >/dev/null 2>&1 ) &
deadline=$(( $(date +%s) + 300 ))
while [ "$(date +%s)" -lt $deadline ]; do
  grep -q " finish$" "$OUT/beat.steps" 2>/dev/null && sleep 3 && break
  if [ -f "$OUT/beat" ] && [ -f "$OUT/beat.steps" ] && grep -q host_steam_session "$OUT/beat.steps"; then
    age=$(( $(date +%s) - $(stat -c %Y "$OUT/beat") ))
    [ $age -gt 20 ] && { echo "FROZEN: main loop stopped ${age}s ago"; break; }
  fi
  sleep 1
done
echo "--- steps"; cat "$OUT/beat.steps" 2>/dev/null
# The exe outlives the proton wrapper; kill it by its runtime path, then the wineserver.
for s in TERM KILL; do for p in $(pgrep -f 'bin.steam.lucid-blocks.exe'); do [ "$p" != "$$" ] && grep -qa 'lucid-blocks.exe' /proc/$p/comm 2>/dev/null && kill -$s $p; done; sleep 2; done
"$P" run wineserver -k >/dev/null 2>&1
echo "--- log"; grep -E "STEAM_PROBE|SCRIPT ERROR" "$L" 2>/dev/null | tail -20
left=0; for p in $(pgrep -f 'bin.steam.lucid-blocks.exe'); do grep -qa 'lucid-blocks.exe' /proc/$p/comm 2>/dev/null && left=1; done; [ $left = 1 ] && echo "WARNING probe still running" || echo "probe stopped"
