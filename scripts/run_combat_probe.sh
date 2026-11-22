#!/usr/bin/env bash
# run_combat_probe.sh <label> <game dir> <mod pck or "none"> <gdre> <work dir> [probe user args...]
# Disposable prefix per label, windowed real renderer.
# Steam is blocked with WINEDLLOVERRIDES: the game sets its own app id, so unsetting SteamAppId is not enough.
set -uo pipefail
LABEL=$1; GAME=$(realpath "$2"); PACK=$3; GDRE=$(realpath "$4"); W=$(realpath -m "$5"); shift 5
HERE=$(dirname "$(realpath "$0")")
P="$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/proton"
RT="$W/bin/$LABEL"; PFX="$W/prefix/$LABEL"; OUT="$W/combat/$LABEL"
[ "$PACK" = none ] || PACK=$(realpath "$PACK")
rm -rf -- "${OUT:?}" "${RT:?}/mods"; mkdir -p "$OUT/pk/mods/combat_probe" "$RT/mods" "$PFX"
cp "$HERE/combat_probe.gd" "$OUT/pk/mods/combat_probe/mod_init.gd"
"$GDRE" --headless "--pck-create=$OUT/pk" --pck-version=2 --pck-engine-version=4.6.0 "--output=$RT/mods/zz-combat.pck" >"$OUT/pack.log" 2>&1
for f in lucid-blocks.exe libgdblocks.windows.template_release.double.x86_64.dll libgodotsteam.windows.template_release.double.x86_64.dll steam_api64.dll; do ln -sfn "$GAME/$f" "$RT/$f"; done
[ "$PACK" = none ] || cp "$PACK" "$RT/mods/lucid-blocks-coop.pck"
export STEAM_COMPAT_DATA_PATH="$PFX" STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
L="$PFX/pfx/drive_c/users/steamuser/AppData/Roaming/lucid blocks/logs/godot.log"; rm -f "$L"
( cd "$RT" && env -u SteamAppId -u SteamGameId WINEDLLOVERRIDES="lsteamclient=;steamclient64=;steamclient=" WINEDEBUG="${WD:--all,+seh}" timeout -k 5 "${TIMEOUT:-420}" "$P" run "$RT/lucid-blocks.exe" --windowed --resolution 800x450 --audio-driver Dummy --max-fps 60 -- "out=Z:$OUT/steps" "$@" >"$OUT/stdout.log" 2>"$OUT/wine.log" ); echo "exit=$?"
WINEPREFIX="$PFX/pfx" "$(dirname "$P")/files/bin/wineserver" -k 2>/dev/null
cp "$L" "$OUT/godot.log" 2>/dev/null
echo "steps=$(wc -l <"$OUT/steps" 2>/dev/null)"; tail -4 "$OUT/steps"
echo "native exceptions:"; grep -aE "code=c00|c0000005|Unhandled" "$OUT/wine.log" | cut -c1-160 | sort | uniq -c | sort -rn | head -6
echo "godot errors:"; grep -aE "^(SCRIPT )?ERROR" "$OUT/godot.log" | cut -c1-150 | sort | uniq -c | sort -rn | head -12
