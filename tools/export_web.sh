#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
~/bin/godot4 --headless --export-release "Web" export/web/index.html
python3 - <<'PY'
from pathlib import Path
p = Path('export/web/index.html')
text = p.read_text()
text = text.replace('"ensureCrossOriginIsolationHeaders":true','"ensureCrossOriginIsolationHeaders":false')
# Browser autoplay policies can leave Godot Web audio suspended when the engine
# starts before a real user gesture, especially inside the Hermelin iframe.
# Gate engine.startGame() behind an explicit click/Enter so AudioContext is
# created/resumed from the gesture and menu music/SFX are actually audible.
text = text.replace('''\t} else {\n\t\tsetStatusMode('progress');\n\t\tengine.startGame({\n\t\t\t'onProgress': function (current, total) {\n\t\t\t\tif (current > 0 && total > 0) {\n\t\t\t\t\tstatusProgress.value = current;\n\t\t\t\t\tstatusProgress.max = total;\n\t\t\t\t} else {\n\t\t\t\t\tstatusProgress.removeAttribute('value');\n\t\t\t\t\tstatusProgress.removeAttribute('max');\n\t\t\t\t}\n\t\t\t},\n\t\t}).then(() => {\n\t\t\tsetStatusMode('hidden');\n\t\t}, displayFailureNotice);\n\t}\n}());''', '''\t} else {\n\t\tsetStatusMode('notice');\n\t\tstatusNotice.innerHTML = '<strong>HACKFIGHTER</strong><br>CLICK / PRESS ENTER TO ENABLE AUDIO';\n\t\tstatusNotice.style.backgroundColor = '#061214';\n\t\tstatusNotice.style.borderColor = '#00f0d0';\n\t\tstatusNotice.style.color = '#dff';\n\t\tstatusOverlay.style.cursor = 'pointer';\n\t\tlet started = false;\n\t\tfunction launchGame() {\n\t\t\tif (started) {\n\t\t\t\treturn;\n\t\t\t}\n\t\t\tstarted = true;\n\t\t\tstatusOverlay.style.cursor = 'default';\n\t\t\tsetStatusMode('progress');\n\t\t\tengine.startGame({\n\t\t\t\t'onProgress': function (current, total) {\n\t\t\t\t\tif (current > 0 && total > 0) {\n\t\t\t\t\t\tstatusProgress.value = current;\n\t\t\t\t\t\tstatusProgress.max = total;\n\t\t\t\t\t} else {\n\t\t\t\t\t\tstatusProgress.removeAttribute('value');\n\t\t\t\t\t\tstatusProgress.removeAttribute('max');\n\t\t\t\t\t}\n\t\t\t\t},\n\t\t\t}).then(() => {\n\t\t\t\tsetStatusMode('hidden');\n\t\t\t\tconst canvas = document.getElementById('canvas');\n\t\t\t\tif (canvas) canvas.focus();\n\t\t\t}, displayFailureNotice);\n\t\t}\n\t\tstatusOverlay.addEventListener('pointerdown', launchGame, { once: true });\n\t\twindow.addEventListener('keydown', function (event) {\n\t\t\tif (event.key === 'Enter' || event.key === ' ') {\n\t\t\t\tlaunchGame();\n\t\t\t}\n\t\t}, { once: true });\n\t}\n}());''')
p.write_text(text)
print('exported_and_patched')
PY
