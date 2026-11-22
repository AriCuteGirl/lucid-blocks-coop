# Lucid Blocks Co-op (5.2.0 build)

Two-player online co-op for **Lucid Blocks** (Steam, game version **5.2.0**, build 26206996),
over Steam invites or direct IP. Tested on Linux under Proton; Windows and Steam Deck are untested by this repo.

**This is not my mod.** It's a ready-to-use build of
[trism-prism's 5.2.0 update](https://github.com/trism-prism/lucid-blocks-coop-updated)
(open as [parkers0405/lucid-blocks-coop#16](https://github.com/parkers0405/lucid-blocks-coop/pull/16))
of [parkers0405's original co-op mod](https://github.com/parkers0405/lucid-blocks-coop).
All co-op code is theirs. The update has no official release yet, so this repo provides a
built `.pck`, Linux/Proton build and test scripts, and install instructions.
Mod authors: if you'd rather this build not be shared here, open an issue and I'll take it down.

Built from `trism-prism/lucid-blocks-coop-updated` commit
[`96e7fc1`](https://github.com/trism-prism/lucid-blocks-coop-updated/commit/96e7fc146c590e2fbc904a9e574a10e88f085ab4)
plus the fixes in [`patches/coop-fixes.patch`](patches/coop-fixes.patch):

- **Crash a few seconds after killing mobs (host and solo).** A killed mob's entry stayed in the
  game's `Dictionary[Node, String]` of saved objects. The mod's 5-second autosave looped over it, and
  release builds of Godot crash on the freed key.
- **Guest dropped with "Chest transaction acknowledgement timed out".** One 5-second timer covered
  steps that may each take 30 seconds. On a host the same timer could disable the player for good.
- **Host slowing to a crawl.** The mod's older copies of two game scripts had lost 5.2.0 safeguards:
  mobs were simulated past 96 blocks, and chunk streaming ran every physics tick instead of once per
  drawn frame, so slow frames queued even more work. Both are back, plus the per-frame chunk time limit.
- **Login timeout** raised from 5 to 20 seconds for slow connections.
- **Host Steam no longer opens the Steam overlay automatically.** Under Proton it could open
  invisibly and block all game input, so the game looked frozen.

## Download

Grab `lucid-blocks-coop.pck` from [Releases](../../releases/latest).

SHA-256: `f8898bd2f17b7e47795a64dd15fbb9c7cf12a2d186d1031b254496acfefc2f3f`

## Install (Windows, Linux, Steam Deck)

1. Steam → Lucid Blocks → ⚙ → Manage → **Browse local files**.
2. Create a folder named `mods` next to `lucid-blocks.exe`.
3. Put `lucid-blocks-coop.pck` in it.
4. Back up your saves first. Co-op writes extra save files.
   - Windows: `%APPDATA%\lucid blocks`
   - Linux/Deck: `steamapps/compatdata/3495730/pfx/drive_c/users/steamuser/AppData/Roaming/lucid blocks`

Both players need the same game version and should use the same `.pck`. Older builds still connect,
but whoever runs one can still crash.
Uninstall: delete the `.pck`.

## Play through Steam

**Host:**
1. Load a world.
2. Click **Host Steam** in the co-op menu, or press `/`, type `/steam_host` and press Enter.
   The status should say *Hosting Steam lobby*.
3. In the **Steam friends list** (the normal Steam window, outside the game), right-click your
   friend → **Invite to Game**.

**Friend:** accept the invite in Steam chat, or right-click the host in the friends list → **Join Game**.
The friend needs to own Lucid Blocks and have the same `.pck` installed.

`/invite` still opens Steam's in-game invite overlay if you want it. If the game "freezes" after
that, press **Shift+Tab** to close the overlay and get your input back.

## Direct IP (fallback)

- Host: in a world, type `/host` or press **F6**.
- Friend: at the main menu, type `/join <host IP>`.
- The host must be reachable: use a VPN like Tailscale/ZeroTier (join with the host's VPN IP),
  or forward the UDP port on the host's router.

## Keys and commands

| Key / command | What it does |
|---|---|
| `T` / Enter | Chat |
| `/` | Command chat |
| F6 / F7 / F8 | Host LAN / join / leave |
| F9 | Teleport to the other player |
| `/tp`, `/list` | Teleport, list players |
| `/pocket`, `/visit` | Your Apotheosis, visit the other player's |
| `/avatar <id>`, `/char-select` | Pick your avatar |
| `/enderchest` | (host) Turn an empty cache cube into a personal chest |

## What's tested

All tests ran with the real 5.2.0 game exe (SHA-256 `cb6ea427…c4a558`) on one Linux PC under Proton
Experimental.

Build 4, 2026-11-22:

- **10 minutes of hosting** a copy of a real world (render distance 192) with a second client, one run
  per build, 15-second slices. Build 3: lowest 9 FPS, typical 63, 7 of 38 slices under 30 FPS. Build 4:
  lowest 45, typical 75, none under 30. The focused-window behaviour was forced for this test.
- **Simulated lag** (the author's `tests/lan/friction.gd` mining scenario through
  `scripts/friction_proton.sh`): 0 disconnects and 0 crashes in 9 runs. Five ran in full and three were
  short (6-7 blocks mined). **One failed:** on the spiky connection the guest connected but never
  finished joining. Cause unknown, and not compared with build 3.
- **Two-client LAN test** (the author's `tests/lan/local_coop.gd`): host 8 checks and guest 11 checks,
  0 failures.
- **Mob fights** were not rerun on this exact build. The version just before it, which also had a
  bookkeeping change that was then removed, had 0 crashes in 131 fights.

Build 3, 2026-11-22: **mob-fighting test** (`scripts/run_combat_probe.sh`): the unmodded game crashed in
0 of 9 runs, build 2 in 10 of 15, build 3 in 0 of 11 (511 fights; 6 of those runs had the crash fix but
not yet the timer fix). The crash fix is unchanged in build 4.

Build 2, 2026-11-21: **Steam host test** (`scripts/run_steam_probe.sh`), 6 checks, 0 failures. Not rerun
since.

In real play over Steam: on build 2 joining worked, but the host crashed and guests were dropped. On
build 3 one host played about 18 minutes without a crash but slowed to about 1 FPS, with floating trees
and smeary camera movement. Build 4 targets the slowdown; whether it also fixes those visuals is unknown.

**Not tested yet:** build 4 over Steam, two real PCs, Windows, Steam Deck, and mixing builds.

## Known limits

- Two players max, and there's no dedicated server.
- Guest pickups take about 0.3-1.2 s on a simulated typical connection, longer if the host is slow.
- The mod replaces some game scripts with older versions, so a few 5.2.0 details are missing (for
  example Fruit Girl's blink and hurt animations).
- `PackedInt32Array` errors can appear in the log after a new world loads. Not investigated yet.
- The log shows resource-leak warnings on shutdown. They're harmless and the original author
  documents them too.

## Build it yourself (Linux)

Requirements: the [Godot 4.6-stable](https://github.com/godotengine/godot-builds/releases/tag/4.6-stable) Linux
editor (`Godot_v4.6-stable_linux.x86_64.zip`, SHA-256 `6bcc59df…6dc06`) and
[GDRE Tools 2.7.4](https://github.com/GDRETools/gdsdecomp/releases/tag/v2.7.4)
(`GDRE_tools-v2.7.4-linux.zip`, SHA-256 `3dc4f124…54758`).

```bash
git clone https://github.com/trism-prism/lucid-blocks-coop-updated mod-src
git -C mod-src checkout 96e7fc146c590e2fbc904a9e574a10e88f085ab4
git -C mod-src apply ../patches/coop-fixes.patch
# Generate the imported assets (the source repo doesn't track .godot/)
./Godot_v4.6-stable_linux.x86_64 --headless --path mod-src/mod/overrides --import
./scripts/build_mod_linux.sh mod-src ./gdre_tools.x86_64 build
# Two real game clients under Proton, throwaway prefixes, Steam blocked (the script does this)
./scripts/test_local_coop_proton.sh "<game dir>" build/lucid-blocks-coop.pck mod-src ./gdre_tools.x86_64 work
```

The game itself is a Godot 4.6 **double-precision** build. No official double-precision 4.6 editor
is published, so the single-precision editor is used only to import the mod's assets.
Asset import isn't byte-reproducible, so your own build's hash will differ from the release's.

The build contains the mod's own scripts and assets plus the mod's **modified versions of the game's own
scripts** (everything under `main/`). It contains none of the game's art, audio or executables.

## Credits

- [parkers0405](https://github.com/parkers0405): original Lucid Blocks co-op mod
- [trism-prism](https://github.com/trism-prism): 5.2.0 update, identity and dimension rework, test suite
- Lucid Blocks by its developers. Buy it on [Steam](https://store.steampowered.com/app/3495730/Lucid_Blocks/).
- This repo: packaging, the fixes listed above, Linux/Proton build and test scripts, and these instructions.
