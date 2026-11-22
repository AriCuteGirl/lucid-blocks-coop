#!/usr/bin/env bash
# friction_proton.sh <label> <game dir> <mod pck> <mod-src> <gdre> <godot> <work> <scenario> <net profile> [timeout]
# Author's friction fixture: two real game exes under Proton, offline Steam, seeded UDP relay in between.
set -uo pipefail
L=$1; GAME=$(realpath "$2"); PACK=$(realpath "$3"); SRC=$(realpath "$4"); GDRE=$(realpath "$5"); GODOT=$(realpath "$6"); W=$(realpath -m "$7"); SC=$8; NET=$9; T=${10:-300}
P="$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/proton"; WS="$(dirname "$P")/files/bin/wineserver"
RUN="$W/friction/$L"; rm -rf -- "${RUN:?}"; mkdir -p "$RUN/probe/mods/local_coop"; echo disposable > "$RUN/.local-coop-scenario"
# Real renderer: keep icon generation on, otherwise item drops have no mesh and release builds crash.
python3 -I - "$SRC/tests/lan/friction.gd" "$RUN/probe/mods/local_coop/mod_init.gd" <<'PY'
import sys
s=open(sys.argv[1]).read(); s=s.replace("        node.skip = true\n","        pass\n"); open(sys.argv[2],"w").write(s)
PY
"$GDRE" --headless "--pck-create=$RUN/probe" --pck-version=2 --pck-engine-version=4.6.0 "--output=$RUN/zz.pck" >/dev/null 2>&1
PORT=$((26000 + RANDOM % 19000)); RP=$((PORT+1))
printf '{"scenario":"%s","disk":"%s","profile":"%s","solo":false,"host_port":%d,"kill_guest_at":"","kill_role":"guest","control":"","control_enters":1,"blocks":%d,"trips":2,"diag":0}' "$SC" "${DISK:-fast}" "$NET" "$PORT" "${BLOCKS:-40}" > "$RUN/config.json"
GP=$PORT; RPID=
if [ "$NET" != clean ]; then GP=$RP; "$GODOT" --headless --script "$SRC/tests/lan/udp_relay.gd" -- $RP $PORT $NET 12345 "$RUN/relay.json" "$RUN/relay.stop" >"$RUN/relay.log" 2>&1 & RPID=$!; sleep 2; fi
go(){ local r=$1 port=$2 rt="$W/bin/$L-$1" px="$W/prefix/$L-$1"; mkdir -p "$rt" "$px"; rm -rf -- "${rt:?}/mods"; mkdir -p "$rt/mods"
  for f in lucid-blocks.exe libgdblocks.windows.template_release.double.x86_64.dll libgodotsteam.windows.template_release.double.x86_64.dll steam_api64.dll; do ln -sfn "$GAME/$f" "$rt/$f"; done
  echo disposable > "$rt/.coop-test-runtime"; printf '[application]\nrun/flush_stdout_on_print=true\n\n[debug]\nsettings/gdscript/always_track_call_stacks=true\n' > "$rt/override.cfg"
  cp "$PACK" "$rt/mods/lucid-blocks-coop.pck"; cp "$RUN/zz.pck" "$rt/mods/zz-local-coop.pck"; rm -f "$px/pfx/drive_c/users/steamuser/AppData/Roaming/lucid blocks/logs/godot.log"
  ( cd "$rt" && env -u SteamAppId -u SteamGameId STEAM_COMPAT_DATA_PATH="$px" STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam" WINEDEBUG=-all,+seh timeout -k 5 $T "$P" run "$rt/lucid-blocks.exe" --windowed --resolution 640x360 --audio-driver Dummy --max-fps 60 -- $r "Z:$RUN" $port >/dev/null 2>"$RUN/$r.wine.log"; echo "$r exit=$?" >> "$RUN/exits" ) & }
go host $PORT; go guest $GP
for i in $(seq 1 $T); do [ "$(wc -l < "$RUN/exits" 2>/dev/null || echo 0)" -ge 2 ] && break; sleep 1; done
touch "$RUN/relay.stop"; sleep 1; [ -n "$RPID" ] && kill $RPID 2>/dev/null
for r in host guest; do px="$W/prefix/$L-$r"; WINEPREFIX="$px/pfx" "$WS" -k 2>/dev/null; cp "$px/pfx/drive_c/users/steamuser/AppData/Roaming/lucid blocks/logs/godot.log" "$RUN/$r.log" 2>/dev/null; done
echo "== $L $SC $NET"; cat "$RUN/exits"
for r in host guest; do echo "$r: $(grep -aoE "LOCAL_COOP_RESULT.*|FRICTION_RESULT.*" "$RUN/$r.log" | tail -1) fails=$(grep -acE 'CHECK .* FAIL' "$RUN/$r.log") reconnects=$(grep -ac 'Reconnecting:' "$RUN/$r.log") crash=$(grep -acE 'code=c0000005' "$RUN/$r.wine.log")"; grep -aE "Reconnecting:|CHECK .* FAIL" "$RUN/$r.log" | sort | uniq -c | head -5; done
