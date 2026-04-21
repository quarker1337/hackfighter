#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
~/bin/godot4 --headless --export-release "Web" export/web/index.html
python3 - <<'PY'
from pathlib import Path
p = Path('export/web/index.html')
text = p.read_text()
text = text.replace('"ensureCrossOriginIsolationHeaders":true','"ensureCrossOriginIsolationHeaders":false')
p.write_text(text)
print('exported_and_patched')
PY
