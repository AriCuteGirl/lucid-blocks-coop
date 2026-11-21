# Lucid Blocks Co-op (5.2.0 build)

Two-player online co-op for **Lucid Blocks** (Steam, game version **5.2.0**, build 26206996),
over Steam invites or direct IP. Works on Windows, Linux and Steam Deck (Proton).

**This is not my mod.** It's a ready-to-use build of
[trism-prism's 5.2.0 update](https://github.com/trism-prism/lucid-blocks-coop-updated)
(open as [parkers0405/lucid-blocks-coop#16](https://github.com/parkers0405/lucid-blocks-coop/pull/16))
of [parkers0405's original co-op mod](https://github.com/parkers0405/lucid-blocks-coop).
All co-op code is theirs. The update has no official release yet, so this repo provides a
built `.pck`, Linux/Proton build and test scripts, and install instructions.
Mod authors: if you'd rather this build not be shared here, open an issue and I'll take it down.

Built from `trism-prism/lucid-blocks-coop-updated` commit
[`96e7fc1`](https://github.com/trism-prism/lucid-blocks-coop-updated/commit/96e7fc146c590e2fbc904a9e574a10e88f085ab4)
plus one small fix in [`patches/`](patches/): **Host Steam no longer opens the Steam overlay
automatically.** Under Proton the invite overlay could open invisibly, and Proton blocks all game
input while the overlay is open, so the game looked frozen.

## Download

Grab `lucid-blocks-coop.pck` from [Releases](../../releases/latest).

SHA-256: `96f7878696464147ab5fc3e0335f15478a1eac83418542765b5de0bb7c748c60`

## Install (Windows, Linux, Steam Deck)

1. Steam → Lucid Blocks → ⚙ → Manage → **Browse local files**.
2. Create a folder named `mods` next to `lucid-blocks.exe`.
3. Put `lucid-blocks-coop.pck` in it.
4. Back up your saves first. Co-op writes extra save files.
   - Windows: `%APPDATA%\lucid blocks`
   - Linux/Deck: `steamapps/compatdata/3495730/pfx/drive_c/users/steamuser/AppData/Roaming/lucid blocks`

Both players need the same game version and the same `.pck`.
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

All tests ran with the real 5.2.0 game exe (SHA-256 `cb6ea427…c4a558`) on Linux under Proton
Experimental (11.0-100), on 2026-11-21 (build 2):

- **Two-client LAN test** (the mod author's `tests/lan/local_coop.gd`): host 8 checks and guest 11
  checks, **0 failures**. It covers joining, guest block edits saved on the host, independent loading
  and dimension travel, reconnecting, cross-dimension teleport, and a clean host shutdown.
- **Steam host test** (`scripts/run_steam_probe.sh` + `steam_host_probe.gd`, windowed, with the
  Steam overlay loaded): with a real logged-in Steam account, Host Steam creates a friends-only
  lobby owned by the host, the Steam host connection comes up, and the overlay stays closed.
  6 checks, 0 failures.

**Not tested yet:** a second Steam account actually joining through an invite, play across two
real PCs, and how it feels in a long session.

## Known limits

- Two players max, and there's no dedicated server.
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
git -C mod-src apply ../patches/0001-no-auto-steam-overlay.patch
# Generate the imported assets (the source repo doesn't track .godot/)
./Godot_v4.6-stable_linux.x86_64 --headless --path mod-src/mod/overrides --import
./scripts/build_mod_linux.sh mod-src ./gdre_tools.x86_64 build
# Two real game clients under Proton, Steam offline, throwaway prefixes
./scripts/test_local_coop_proton.sh "<game dir>" build/lucid-blocks-coop.pck mod-src ./gdre_tools.x86_64 work
```

The game itself is a Godot 4.6 **double-precision** build. No official double-precision 4.6 editor
is published, so the single-precision editor is used only to import the mod's assets. The game
loads them fine, and the remote player's avatar renders and animates.

The build contains no game files, only the mod's own scripts and assets.

## Credits

- [parkers0405](https://github.com/parkers0405): original Lucid Blocks co-op mod
- [trism-prism](https://github.com/trism-prism): 5.2.0 update, identity and dimension rework, test suite
- Lucid Blocks by its developers. Buy it on [Steam](https://store.steampowered.com/app/3495730/Lucid_Blocks/).
- This repo: packaging, the Proton overlay-freeze fix, Linux/Proton build and test scripts, and these instructions.
