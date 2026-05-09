---
name: hackfighter2-repo-guide
description: Use when a Hermes agent starts work in the HACKFIGHTER 2 Godot repository and needs repo structure, build/test commands, asset/licensing conventions, and safe development workflow.
version: 1.0.0
author: HACKFIGHTER contributors
license: MIT
metadata:
  hermes:
    tags: [hackfighter2, godot, fighting-game, repo-guide, web-export]
    related_skills: [godot-web-game-release]
---

# HACKFIGHTER 2 Repo Guide

## Overview

This skill orients Hermes agents inside the HACKFIGHTER 2 repository. It intentionally avoids local machine paths, private ports, personal backup locations, and chat-specific artifact runner details. Treat paths as relative to the repository root.

HACKFIGHTER 2 is a Godot 4 browser fighting-game project. It uses real HACKFIGHTER character/stage assets, a dark research-console menu shell, fixed low-resolution gameplay presentation, and Web export tooling for browser play.

## When to Use

- Starting a new task in this repository.
- Editing Godot scripts/scenes/assets.
- Updating README, licenses, release plans, or GitHub Pages deployment.
- Building or verifying the Web export.
- Debugging menu/gameplay regressions in the exported browser build.

Do not assume any previous Hermes session context. Inspect the live repo first.

## Repository Quick Facts

- Engine family: Godot 4.6.x.
- Main scene: `res://scenes/Main.tscn`.
- Logical resolution: `512x288`.
- Web export preset: `Web`.
- Export output: `export/web/index.html`.
- Convenience build command: `make export-web`.
- Generated export output: `export/` and should stay ignored.
- Code license: MIT (`LICENSE`).
- Creative asset license: see `ASSET_LICENSE.md`.

## Important Paths

```text
.
├── assets/
│   ├── audio/                  # announcer, gameplay SFX, music, specials
│   ├── real/characters/        # production fighter sprite sheets
│   ├── real/stages/            # production stage art
│   ├── screenshots/            # README/docs screenshots
│   └── ui/                     # UI/HUD art
├── docs/plans/                 # implementation plans
├── hermes/skills/              # repo-local Hermes skills for future agents
├── scenes/                     # Godot scenes
├── scripts/                    # GDScript gameplay, stage, sprite/audio systems
├── tools/
│   ├── export_web.sh           # canonical Web export command
│   └── capture_menu_screenshot.js
├── export_presets.cfg          # Godot Web export preset
├── Makefile                    # convenience targets
└── project.godot               # Godot project file
```

Core scripts:

- `scripts/main.gd`: app/menu/fighter-select/game loop orchestration, HUD, round flow, combat coordinator.
- `scripts/player.gd`: fighter movement, attacks, hitstun/blockstun, animation state, per-fighter behavior.
- `scripts/sprite_loader.gd`: runtime SpriteFrames construction from fighter sprite sheets.
- `scripts/stage.gd`: real HACKFIGHTER city stage setup and stage bounds.
- `scripts/sound_manager.gd`: audio asset loading and sound/music calls, including Web bridge calls when available.
- `scripts/simple_ai.gd`: CPU input decisions.
- `scripts/health_bar.gd`: HUD health bar behavior.

Core scenes:

- `scenes/Main.tscn`
- `scenes/Player.tscn`
- `scenes/Stage.tscn`
- `scenes/HealthBar.tscn`

## First Commands in Any Session

Run these before editing:

```bash
git status --short --branch
grep -E 'config/name|run/main_scene|config/features|viewport_width|viewport_height' project.godot
sed -n '1,120p' Makefile
sed -n '1,160p' tools/export_web.sh
grep -E 'name=|platform=|export_path|ensure_cross|html/canvas|focus_canvas' export_presets.cfg
```

If the task touches art/audio, also inspect relevant asset directories:

```bash
find assets -maxdepth 3 -type d | sort
```

If the task touches licensing/public release:

```bash
find . -maxdepth 4 \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname '*license*' \) -print | sort
```

## Build and Local Run

Build the Web export:

```bash
make export-web
```

The project-local export script handles project-specific Web fixes. Do not bypass it with an ad-hoc Godot command unless you are deliberately debugging the export script.

Serve locally for browser testing:

```bash
python3 -m http.server 8799 --bind 127.0.0.1 --directory export/web
```

Open:

```text
http://127.0.0.1:8799/index.html
```

Click the HACKFIGHTER audio/start gate or press Enter. The menu should load afterward.

## Expected Menu/UI Identity

The project is not a generic Street Fighter clone shell. Preserve the HACKFIGHTER identity:

- dark black / near-black UI shell;
- cyan/teal accents;
- research-console / lab / Teknium / Nous-inspired feel;
- title `HACKFIGHTER`;
- Japanese subtitle `ハックファイター 2083`;
- menu language such as `START SIMULATION`, `CONTROL MAP`, `SYSTEM OPTIONS`, `CPU PROFILE`.

Avoid reintroducing generic retro-arcade wording or third-party fighting-game branding in the main shell.

## Controls

Menu:

- Navigate: `W` / `S`
- Confirm: `Enter`
- Back from submenus / fighter select: `U` or `J`
- Fighter select side change: `A` / `D`

Gameplay:

- Move left/right: `A` / `D`
- Jump: `W`
- Crouch: `S`
- Light punch: `U` or `J`
- Heavy punch: `I` or `K`
- Light kick: `O` or `L`
- Heavy kick: `P` or `;`

Debug/development:

- `F8`: toggle CPU AI
- `F9`: toggle debug overlay

## Development Workflow

1. Make a small, focused change.
2. Run syntax/static sanity checks where applicable.
3. Build the Web export with `make export-web` if behavior or exported docs changed.
4. Verify in the browser build, not just by reading scripts.
5. For visual changes, capture or ask for visual confirmation before moving on.
6. Keep generated `export/` out of git.
7. Commit in small checkpoints with conventional messages.

Useful checks:

```bash
git diff --check
node --check tools/capture_menu_screenshot.js 2>/dev/null || true
```

Use Godot headless export as the primary compilation check:

```bash
make export-web
```

## Web Export Gotchas

- Keep Godot binary and export templates on the same version family.
- `tools/export_web.sh` is the canonical export entrypoint.
- The exported `index.html` must keep `ensureCrossOriginIsolationHeaders:false` unless the game intentionally uses threads/SharedArrayBuffer.
- Do not add COOP/COEP headers for normal browser/static hosting.
- Public hosting must be HTTPS; GitHub Pages satisfies this.
- Browser audio needs a real user gesture. Preserve the click/Enter audio gate.
- Localhost HTTP is acceptable for local testing, but plain HTTP over a LAN IP may fail browser secure-context checks.

## Fighting-Game Architecture Notes

- `Main.gd` coordinates both players, round state, menu/app state, HUD, combat pair checks, and camera/stage interactions.
- `Player.gd` should own fighter-local movement, animation, attack state, hitstun/blockstun, and sprite orientation.
- Hitbox push direction should be computed by the coordinator that knows both player positions.
- Fighter auto-facing should be based on player positions, not movement input.
- AI should feed P2 input as a thin override rather than rewriting the scene controller.
- AI attack input must behave like edge-triggered `just pressed`, not a raw held dictionary flag.
- Ground attacks should be restricted to standing/grounded states unless separate crouch/jump attacks are explicitly authored.
- Blocking should only trigger when holding back during an opponent attack; holding back alone should still walk backward.

## Sprite and Animation Notes

- Real fighters are loaded from sprite sheets by `scripts/sprite_loader.gd`.
- Sheet slicing and perceived on-screen scale are separate issues; correct frame dimensions do not guarantee correct visual mass.
- Always guard `AnimatedSprite2D.play()` calls so missing/empty animations cannot silently kill behavior in Web export.
- In Godot 4, use `SpriteFrames.get_frame_texture()`, not old Godot 3-style API names.
- Keep missing move placeholders explicit when a production fighter has partial animation coverage.

## HUD/Menu Visibility Rule

When adding HUD or overlay nodes, update the central visibility toggles. If menu state looks broken after adding HUD elements, first check whether a new gameplay overlay remains visible during menu states before rewriting app-state logic.

## Asset and License Conventions

- Source code/scripts/tooling/docs: MIT license.
- Creative assets: see `ASSET_LICENSE.md`.
- Add specific notices next to any future third-party or specially licensed assets.
- Per-asset notices override the general asset license.
- Do not mix generated Web export artifacts into source commits.

## Public Release / GitHub Pages

A plan for GitHub Pages may live under `docs/plans/`. The recommended approach is:

1. Make `tools/export_web.sh` CI-friendly with configurable `GODOT_BIN`.
2. Ensure export writes `export/web/.nojekyll`.
3. Add a GitHub Actions Pages workflow that installs Godot and templates, runs `tools/export_web.sh`, validates `index.html`, `.wasm`, `.pck`, `.nojekyll`, and deploys `export/web`.
4. Enable GitHub Pages source as GitHub Actions in repository settings.
5. Smoke-test the public HTTPS URL before adding it to README.

Expected project-page format:

```text
https://OWNER.github.io/REPO/
```

## Verification Checklist

Before finalizing a task:

- [ ] `git status --short --branch` reviewed.
- [ ] Relevant files inspected before editing.
- [ ] `git diff --check` passes.
- [ ] `make export-web` run for gameplay/Web/export changes.
- [ ] Browser build tested for visual/gameplay changes.
- [ ] README/docs updated when commands or public behavior changed.
- [ ] No generated `export/` files staged.
- [ ] Commit includes only intended source/docs/assets.

## Common Pitfalls

1. Editing from memory instead of inspecting current files.
2. Trusting local headless diagnostics as proof that Web export works. Browser/WASM can fail differently.
3. Forgetting the audio/start gate requirement and assuming autoplay works.
4. Replacing the stable scene controller wholesale for a small feature. Prefer incremental layers.
5. Adding new HUD nodes without adding them to visibility toggles.
6. Reintroducing old prototype/third-party branding into the HACKFIGHTER shell.
7. Treating asset frame size as final visual scale.
8. Committing `export/` build output.
9. Using environment-specific paths in docs or skills.
