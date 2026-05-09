# HACKFIGHTER 2

A Godot 4 browser fighting-game prototype with a dark HACKFIGHTER / Teknium / Nous-research shell, real character sprite-sheet support, Web export, menu audio unlock, and browser-playable build tooling.

![HACKFIGHTER 2 loading menu](assets/screenshots/loading-menu.png)

## Video

Watch the linked gameplay / project video here:

https://www.youtube.com/watch?v=kSgEnp6wBP8

## Current game state

- Engine: Godot 4.6.x
- Main scene: `res://scenes/Main.tscn`
- Native logical resolution: `512x288`
- Default shell: HACKFIGHTER main menu with Japanese subtitle `ハックファイター 2083`
- Current real fighters/assets: Teknium and Lobster
- Current real stage/assets: HACKFIGHTER city stage
- Export target: Web / HTML5
- Audio: Godot sound manager plus a browser audio bridge for Web exports, started only after a real click or Enter key press

## Controls

Menu:

- Navigate: `W` / `S`
- Confirm: `Enter`
- Back from submenus / fighter select: `U` or `J`
- Fighter select side change: `A` / `D`

In fight:

- Move left/right: `A` / `D`
- Jump: `W`
- Crouch: `S`
- Light punch: `U` or `J`
- Heavy punch: `I` or `K`
- Light kick: `O` or `L`
- Heavy kick: `P` or `;`

Debug / development:

- `F8`: toggle CPU AI
- `F9`: toggle debug overlay

## Repository layout

```text
.
├── assets/
│   ├── audio/                  # announcer, gameplay SFX, music, specials
│   ├── real/characters/        # production fighter sprite sheets
│   ├── real/stages/            # production stage art
│   ├── screenshots/            # README screenshots
│   └── ui/                     # UI/HUD art
├── scenes/                     # Godot scenes
├── scripts/                    # GDScript gameplay, stage, sprite/audio systems
├── tools/
│   ├── export_web.sh           # canonical Web export command
│   └── capture_menu_screenshot.js
├── export_presets.cfg          # Godot Web export preset
├── Makefile                    # convenience targets
└── project.godot               # Godot project file
```

`export/` is build output and is intentionally ignored by git.

## Install / setup

These steps assume Linux. Commands are written from the project root unless noted.

### 1. Install Godot 4.6.2

Download Godot 4.6.2 and make sure the project-local tooling can run it as `~/bin/godot4`:

```bash
mkdir -p ~/bin
cd /tmp
curl -L -o godot.zip "https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_linux.x86_64.zip"
unzip -o godot.zip
install -m 700 Godot_v4.6.2-stable_linux.x86_64 ~/bin/godot4-4.6.2
ln -sfn ~/bin/godot4-4.6.2 ~/bin/godot4
~/bin/godot4 --version
```

Expected version family: `4.6.2.stable`.

Important: use the same Godot version as the export templates. A mismatched binary/templates pair can create a WebAssembly build that loads the splash screen but fails at runtime.

### 2. Install Godot Web export templates

```bash
mkdir -p ~/.local/share/godot/export_templates/4.6.2.stable
cd /tmp
curl -L -o godot_web_templates.tpz "https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_export_templates.tpz"
python3 - <<'PY'
import zipfile
from pathlib import Path
out = Path.home() / ".local/share/godot/export_templates/4.6.2.stable"
with zipfile.ZipFile("godot_web_templates.tpz", "r") as z:
    z.extractall(out)
PY
mv ~/.local/share/godot/export_templates/4.6.2.stable/templates/* ~/.local/share/godot/export_templates/4.6.2.stable/
rmdir ~/.local/share/godot/export_templates/4.6.2.stable/templates
```

The `mv` step matters: the template archive extracts into a nested `templates/` directory, but Godot expects the files directly under `4.6.2.stable/`.

### 3. Clone / enter the project

```bash
git clone <repo-url>
cd stoatfighter2-godot
```

If you already have this working tree, just enter it:

```bash
cd ~/hackfighter2-clean/stoatfighter2-godot
```

### 4. Optional: install Node dependencies for screenshot automation

The game itself does not require Node. The README screenshot helper uses Puppeteer.

If `require('puppeteer')` already works, you can skip this. Otherwise install it in your normal development environment:

```bash
npm install puppeteer
```

## Running in the Godot editor

From the project root:

```bash
~/bin/godot4 --path .
```

Or open this folder from the Godot Project Manager.

## Building the Web export

Use the project-local export entrypoint, not an ad-hoc Godot command:

```bash
make export-web
```

This runs:

```bash
./tools/export_web.sh
```

The script exports to:

```text
export/web/index.html
```

It also performs project-specific Web-export fixes:

- patches `ensureCrossOriginIsolationHeaders` to `false`
- avoids COOP/COEP iframe breakage
- copies real audio files into `export/web/audio_bridge/`
- injects the browser audio unlock / bridge used by the Web build

## Serving the Web export locally

After `make export-web`, serve the build from `export/web`:

```bash
python3 -m http.server 8799 --bind 127.0.0.1 --directory export/web
```

Then open:

```text
http://127.0.0.1:8799/index.html
```

Click the HACKFIGHTER audio gate or press `Enter`, then the main menu should appear.

Note for local/LAN testing: localhost HTTP is acceptable for browser secure-context requirements. If you serve to another machine over a LAN IP, use HTTPS or an SSH tunnel; plain `http://<lan-ip>` can fail Godot Web secure-context checks.

## Capturing the README menu screenshot

With the local server running on port `8799`:

```bash
node tools/capture_menu_screenshot.js assets/screenshots/loading-menu.png http://127.0.0.1:8799/index.html
```

The script opens the Web build in Puppeteer, clicks the initial audio gate, waits for the HACKFIGHTER menu, and writes the screenshot used by this README.

## Development notes

- Keep source art and scripts in git.
- Do not commit `export/`; rebuild it with `make export-web`.
- Keep Web export fixes inside `tools/export_web.sh` so future builds do not drift.
- For iframe embedding, do not add COOP/COEP headers. The project is configured for Web builds without SharedArrayBuffer/thread isolation.
- When changing visible game behavior, rebuild with `make export-web` and verify in the browser build, not only in headless/editor diagnostics.

## Backup

A tarball backup of the current working tree can be made from the parent folder with:

```bash
tar --exclude='.git' --exclude='export' -czf ~/hackfighter/backup_09052026.tar.gz -C ~/hackfighter2-clean stoatfighter2-godot
```

If you need a complete git-aware archive of the tracked source only, run this from the project root:

```bash
git archive --format=tar.gz -o ~/hackfighter/backup_09052026.tar.gz HEAD
```
