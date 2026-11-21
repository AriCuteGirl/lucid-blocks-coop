#!/usr/bin/env bash
# Linux/Proton port of mod-src/scripts/test_local_coop.ps1 (smoke scenario, clean network).
# Runs the real lucid-blocks.exe twice (host + guest) under Proton, each in its own
# disposable Wine prefix and runtime folder. Steam is not used (no SteamAppId), so
# GodotSteam starts offline and the fixture connects over direct ENet on localhost.
# Usage: test_local_coop_proton.sh <game dir> <mod pck> <mod-src dir> <gdre> <work dir>
set -euo pipefail
GAME=$(realpath "$1"); PACK=$(realpath "$2"); SRC=$(realpath "$3"); GDRE=$(realpath "$4"); WORK=$(realpath -m "$5")
PROTON="${PROTON:-$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/proton}"
TIMEOUT="${TIMEOUT:-420}"
HEADLESS="${HEADLESS:-1}"

RUN="$WORK/runs/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN/probe/mods/local_coop"
echo disposable > "$RUN/.local-coop-scenario"
cp "$SRC/tests/lan/local_coop.gd" "$RUN/probe/mods/local_coop/mod_init.gd"
"$GDRE" --headless "--pck-create=$RUN/probe" --pck-version=2 --pck-engine-version=4.6.0 \
  "--output=$RUN/zz-local-coop.pck" > "$RUN/pack.log" 2>&1
[ -f "$RUN/zz-local-coop.pck" ] || { cat "$RUN/pack.log"; exit 1; }
PORT=$(( 26000 + RANDOM % 19000 ))
echo "LOCAL_COOP_RUN $RUN port=$PORT"

declare -A PIDS
launch() {
  local role=$1 rt="$WORK/bin/$1" pfx="$WORK/prefix/$1"
  mkdir -p "$rt" "$pfx" "$RUN/$role"
  rm -rf "$rt/mods"; mkdir -p "$rt/mods"
  # Symlinks: no 1.5 GB copy; Wine reports the link's own path as the exe path,
  # so the game's mod loader reads $rt/mods, not the real install's.
  for f in lucid-blocks.exe libgdblocks.windows.template_release.double.x86_64.dll \
           libgodotsteam.windows.template_release.double.x86_64.dll steam_api64.dll; do
    ln -sfn "$GAME/$f" "$rt/$f"
  done
  echo disposable > "$rt/.coop-test-runtime"
  cp "$PACK" "$rt/mods/lucid-blocks-coop.pck"
  cp "$RUN/zz-local-coop.pck" "$rt/mods/zz-local-coop.pck"
  local args=(--max-fps 60)
  [ "$HEADLESS" = 1 ] && args=(--headless "${args[@]}") || args+=(--windowed --resolution 960x540)
  ( cd "$rt" && env -u SteamAppId -u SteamGameId \
      STEAM_COMPAT_DATA_PATH="$pfx" STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam" \
      WINEDEBUG=-all \
      "$PROTON" run "$rt/lucid-blocks.exe" "${args[@]}" -- "$role" "Z:${RUN}" "$PORT" \
      > "$RUN/$role.stdout.log" 2> "$RUN/$role.stderr.log" ) &
  PIDS[$role]=$!
  echo "LOCAL_COOP_STARTED $role ${PIDS[$role]}"
}

cleanup() {
  for role in host guest; do
    STEAM_COMPAT_DATA_PATH="$WORK/prefix/$role" STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam" \
      "$PROTON" run wineserver -k >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

launch host
launch guest
deadline=$(( $(date +%s) + TIMEOUT ))
declare -A CODE
for role in host guest; do
  while kill -0 "${PIDS[$role]}" 2>/dev/null; do
    if [ -f "$RUN/${role}_failed.json" ]; then echo "ROLE FAILED: $role"; cat "$RUN/${role}_failed.json"; fi
    [ "$(date +%s)" -ge "$deadline" ] && { echo "OVERALL DEADLINE"; break 2; }
    sleep 1
  done
  wait "${PIDS[$role]}" 2>/dev/null; CODE[$role]=$?
done

fail=0
for role in host guest; do
  # A GUI-subsystem exe's stdout doesn't reach us under Wine; read Godot's own log file.
  glog="$WORK/prefix/$role/pfx/drive_c/users/steamuser/AppData/Roaming/lucid blocks/logs/godot.log"
  cp "$glog" "$RUN/$role.godot.log" 2>/dev/null || true
  log=$(cat "$RUN/$role.godot.log" "$RUN/$role.stdout.log" "$RUN/$role.stderr.log" 2>/dev/null)
  errs=$(grep -cE 'SCRIPT ERROR:|Parse Error|Compile Error|CrashHandlerException|LOCAL_COOP_CHECK .* FAIL' <<<"$log" || true)
  res=$(grep -oE "LOCAL_COOP_RESULT $role [0-9]+ checks [0-9]+ failures" <<<"$log" || echo "no result")
  echo "LOCAL_COOP_PROCESS $role exit=${CODE[$role]:-?} script_errors=$errs complete=$([ -f "$RUN/${role}_complete.json" ] && echo yes || echo no) $res"
  grep -qE "LOCAL_COOP_RESULT $role [0-9]+ checks 0 failures" <<<"$log" && [ "$errs" = 0 ] || fail=1
done
[ $fail = 0 ] && echo LOCAL_COOP_SMOKE_PASS || { echo LOCAL_COOP_SMOKE_FAIL; exit 1; }
