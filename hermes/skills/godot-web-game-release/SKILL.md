---
name: godot-web-game-release
description: Use when working on a Godot 4 browser game that exports to Web/HTML5, needs public docs/licensing/screenshots, or should be deployed to static hosting such as GitHub Pages.
version: 1.0.0
author: HACKFIGHTER contributors
license: MIT
metadata:
  hermes:
    tags: [godot, web-export, github-pages, documentation, release]
    related_skills: []
---

# Godot Web Game Release

## Overview

Use this skill for Godot 4 projects that ship as browser-playable Web/HTML5 exports. It captures the workflow used for HACKFIGHTER 2 without relying on any one developer's machine paths, private ports, or local artifact runner setup.

The main idea is: keep the Godot project source clean, keep generated `export/` output out of git, automate Web export fixes in a project-local script, verify the result in a real browser build, and publish the static Web export through a host that serves HTTPS.

## When to Use

- Creating or reviewing a README for a browser-playable Godot game.
- Setting up repeatable Godot Web exports.
- Debugging blank/white Web builds caused by browser isolation headers.
- Preparing GitHub Pages deployment for a Godot Web export.
- Adding split licensing for code vs. creative assets.
- Capturing a real screenshot from the exported Web build.

Do not use this as a generic Godot gameplay architecture guide. It is specifically about release/docs/Web export/public hosting.

## Project Discovery Checklist

Before changing anything, inspect the project instead of guessing:

```bash
git status --short --branch
grep -E 'config/name|run/main_scene|config/features|viewport_width|viewport_height' project.godot
sed -n '1,120p' Makefile 2>/dev/null || true
sed -n '1,200p' tools/export_web.sh 2>/dev/null || true
grep -E 'name=|platform=|export_path|ensure_cross|html/canvas|focus_canvas' export_presets.cfg 2>/dev/null || true
find assets -maxdepth 3 -type d | sort | sed -n '1,120p'
```

Record:

- Godot version/features.
- Main scene path.
- Logical resolution.
- Export preset name and export path.
- Whether a project-local export script exists.
- Whether `export/` is ignored.
- Whether the game has an audio/start gate.
- Existing license files and per-asset notices.

## Web Export Pattern

Prefer a project-local export script, commonly `tools/export_web.sh`, and a convenience target:

```make
.PHONY: export-web

export-web:
	./tools/export_web.sh
```

The export script should:

1. Run from the project root.
2. Use a configurable Godot binary while preserving local defaults:

```bash
GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot4}"
"$GODOT_BIN" --headless --export-release "Web" export/web/index.html
```

3. Patch exported HTML so cross-origin isolation is disabled when threads/SharedArrayBuffer are not required:

```python
from pathlib import Path
p = Path('export/web/index.html')
text = p.read_text()
text = text.replace('"ensureCrossOriginIsolationHeaders":true', '"ensureCrossOriginIsolationHeaders":false')
p.write_text(text)
```

4. Add a `.nojekyll` marker for GitHub Pages:

```python
Path('export/web/.nojekyll').write_text('')
```

5. Keep any export-shell audio unlock/bridge logic in the same export script so rebuilds do not drift.

## COOP/COEP Rule

For non-threaded Godot Web builds, do not add COOP/COEP headers just because a guide says to. They can break iframes and static-host subresource loading.

Safe default:

- `ensureCrossOriginIsolationHeaders=false` in exported HTML.
- no `Cross-Origin-Opener-Policy` header.
- no `Cross-Origin-Embedder-Policy` header.
- serve static files over HTTPS for public hosting.

Why: COEP `require-corp` can block `.wasm`, `.pck`, `.js`, audio, or image resources unless every subresource has compatible resource-policy headers. If the game does not use threads/SharedArrayBuffer, isolation is unnecessary risk.

## Local Browser Verification

After exporting:

```bash
make export-web
python3 -m http.server 8799 --bind 127.0.0.1 --directory export/web
```

Open:

```text
http://127.0.0.1:8799/index.html
```

For automation, use Puppeteer from the project root so module resolution is predictable. Avoid `page.waitForTimeout()` because not all installed Puppeteer versions expose it:

```js
const puppeteer = require('puppeteer');
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720, deviceScaleFactor: 1 });
  await page.goto('http://127.0.0.1:8799/index.html', {
    waitUntil: 'domcontentloaded',
    timeout: 60000,
  });
  await wait(1200);
  await page.mouse.click(640, 360); // click audio/start gate if present
  await wait(6000);
  await page.screenshot({ path: 'assets/screenshots/loading-menu.png', fullPage: true });
  await browser.close();
})();
```

Verify screenshots with a real visual check when UI correctness matters.

## README Contents for Browser-Playable Godot Games

A useful README should include:

- Project name and one-paragraph description.
- Screenshot from the real Web build, not an editor-only image.
- Video/demo links if available.
- Current game state: engine version, main scene, logical resolution, playable characters/stages, export target.
- Controls for menu and gameplay.
- Repository layout.
- Install/setup steps for Godot and Web export templates.
- How to run in the editor.
- How to build the Web export.
- How to serve locally.
- Web-specific caveats: HTTPS, audio gate, COOP/COEP, generated `export/` ignored.
- License section that distinguishes code from creative assets.

## Split Licensing Pattern

For public game repositories, use split licensing unless the project owner specifies otherwise:

- `LICENSE`: code, scripts, project config, build tooling, documentation. MIT is a common permissive default.
- `ASSET_LICENSE.md`: non-code creative assets such as sprites, stages, UI art, screenshots, music, and SFX. For permissive asset reuse with attribution, a common default is CC BY 4.0; choose a stricter license only if the project owner wants to restrict commercial reuse or derivatives.

Before adding licenses:

```bash
find . -maxdepth 4 \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname '*license*' \) -print | sort
```

Do not overwrite or contradict existing third-party notices. State that per-asset notices override the general asset license.

## GitHub Pages Deployment Pattern

Godot Web exports are static sites and can be published with GitHub Pages.

Preferred architecture:

1. Keep `export/` ignored.
2. Add a GitHub Actions workflow that installs the exact Godot version and matching export templates.
3. Run the project-local export script.
4. Assert required output exists:

```bash
test -f export/web/index.html
test -f export/web/index.wasm
test -f export/web/index.pck
test -f export/web/.nojekyll
grep -q '"ensureCrossOriginIsolationHeaders":false' export/web/index.html
```

5. Upload `export/web` using `actions/upload-pages-artifact`.
6. Deploy using `actions/deploy-pages`.
7. In repository settings, set Pages source to GitHub Actions.

Expected project-page URL format:

```text
https://OWNER.github.io/REPO/
```

Godot's relative export paths normally work from this subpath.

## Verification Checklist

- [ ] `make export-web` succeeds locally.
- [ ] `export/web/index.html`, `.wasm`, `.pck`, and `.nojekyll` exist.
- [ ] Exported HTML has `ensureCrossOriginIsolationHeaders:false`.
- [ ] Local browser URL loads the game.
- [ ] Audio/start gate works after real click or Enter.
- [ ] Main menu appears in a screenshot from the Web build.
- [ ] `export/` remains ignored.
- [ ] README documents install, run, export, serve, controls, and license.
- [ ] GitHub Pages workflow builds from source and uploads `export/web`.
- [ ] Public HTTPS URL loads and user visually confirms the game.

## Common Pitfalls

1. Hardcoding a developer-specific Godot binary path in CI. Use `GODOT_BIN` or another environment variable.
2. Using mismatched Godot binary and export templates. Keep versions aligned.
3. Trusting `export_presets.cfg` alone for cross-origin isolation. Check and patch exported `index.html`.
4. Committing generated `export/` output to source branches. Prefer CI artifacts.
5. Forgetting `.nojekyll` for GitHub Pages.
6. Declaring success from a local headless export only. Always verify in the browser build.
7. Assuming audio works without a user gesture. Modern browsers require click/touch/key activation.
8. Adding a public play URL to README before the deployed URL has been smoke-tested.
