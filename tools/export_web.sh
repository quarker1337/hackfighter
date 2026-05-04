#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
~/bin/godot4 --headless --export-release "Web" export/web/index.html
python3 - <<'PY'
from pathlib import Path
import shutil, json
root = Path('.')
web = root / 'export/web'
p = web / 'index.html'
text = p.read_text()
text = text.replace('"ensureCrossOriginIsolationHeaders":true','"ensureCrossOriginIsolationHeaders":false')

# Copy real game audio files next to the web export. These are triggered ONLY
# from Godot SoundManager via JavaScriptBridge, not from browser key events.
audio_dir = web / 'audio_bridge'
audio_dir.mkdir(parents=True, exist_ok=True)
manifest = {
    'fight': 'assets/audio/announcer/Fight.mp3',
    'fight_alt': 'assets/audio/announcer/Fight_2.mp3',
    'ready': 'assets/audio/announcer/Ready.mp3',
    'round_one': 'assets/audio/announcer/Round_One.mp3',
    'round_two': 'assets/audio/announcer/Round_Two.mp3',
    'round_three': 'assets/audio/announcer/Round_Three.mp3',
    'p1_wins': 'assets/audio/announcer/PlayerOne_Wins.mp3',
    'p2_wins': 'assets/audio/announcer/PlayerTwo_Wins.mp3',
    'draw': 'assets/audio/announcer/Draw.mp3',
    'you_win': 'assets/audio/announcer/You_Win.mp3',
    'you_lose': 'assets/audio/announcer/You_Loose.mp3',
    'perfect': 'assets/audio/announcer/Perfect.mp3',
    'menu_cursor': 'assets/audio/01 Select Screen & World Map/REMOVED_AUDIO_02 - Move Cursor.wav',
    'menu_select': 'assets/audio/01 Select Screen & World Map/REMOVED_AUDIO_03 - Selection.wav',
    'menu_open': 'assets/audio/01 Select Screen & World Map/REMOVED_AUDIO_04 - Plane.wav',
    'light_attack': 'assets/audio/04 Moves & Hits/REMOVED_AUDIO_38 - Light Attack.wav',
    'medium_attack': 'assets/audio/04 Moves & Hits/REMOVED_AUDIO_39 - Medium Attack.wav',
    'hard_attack': 'assets/audio/04 Moves & Hits/REMOVED_AUDIO_40 - Hard Attack1.wav',
    'jab_hit': 'assets/audio/04 Moves & Hits/REMOVED_AUDIO_42 - Jab Hit.wav',
    'fierce_hit': 'assets/audio/04 Moves & Hits/REMOVED_AUDIO_44 - Fierce Hit.wav',
    'short_hit': 'assets/audio/04 Moves & Hits/REMOVED_AUDIO_45 - Short Hit.wav',
    'roundhouse_hit': 'assets/audio/04 Moves & Hits/REMOVED_AUDIO_47 - Roundhouse Hit.wav',
    'blocked': 'assets/audio/04 Moves & Hits/REMOVED_AUDIO_51 - Blocked.wav',
    'hit_ground': 'assets/audio/04 Moves & Hits/REMOVED_AUDIO_52 - Hit the ground.wav',
    'landing': 'assets/audio/04 Moves & Hits/REMOVED_AUDIO_53 - Landing.wav',
    'grunt1': 'assets/audio/05 Character Voices/REMOVED_AUDIO_63 - Grunt1.wav',
    'grunt2': 'assets/audio/05 Character Voices/REMOVED_AUDIO_64 - Grunt2.wav',
    'ko_male': 'assets/audio/05 Character Voices/REMOVED_AUDIO_67 - KO Male.wav',
}
bridge_urls = {}
for key, rel in manifest.items():
    src = root / rel
    if not src.exists():
        continue
    dst = audio_dir / f'{key}{src.suffix.lower()}'
    shutil.copy2(src, dst)
    bridge_urls[key] = f'audio_bridge/{dst.name}'

old_tail = '''\t} else {\n\t\tsetStatusMode('progress');\n\t\tengine.startGame({\n\t\t\t'onProgress': function (current, total) {\n\t\t\t\tif (current > 0 && total > 0) {\n\t\t\t\t\tstatusProgress.value = current;\n\t\t\t\t\tstatusProgress.max = total;\n\t\t\t\t} else {\n\t\t\t\t\tstatusProgress.removeAttribute('value');\n\t\t\t\t\tstatusProgress.removeAttribute('max');\n\t\t\t\t}\n\t\t\t},\n\t\t}).then(() => {\n\t\t\tsetStatusMode('hidden');\n\t\t}, displayFailureNotice);\n\t}\n}());'''
new_tail = '''\t} else {\n\t\tsetStatusMode('notice');\n\t\tstatusNotice.innerHTML = '<strong>HACKFIGHTER</strong><br>CLICK / PRESS ENTER TO ENABLE AUDIO';\n\t\tstatusNotice.style.backgroundColor = '#061214';\n\t\tstatusNotice.style.borderColor = '#00f0d0';\n\t\tstatusNotice.style.color = '#dff';\n\t\tstatusOverlay.style.cursor = 'pointer';\n\t\tconst hackfighterAudioContexts = [];\n\t\tfunction installHackfighterAudioUnlock(name) {\n\t\t\tconst OriginalAudioContext = window[name];\n\t\t\tif (!OriginalAudioContext || OriginalAudioContext.__hackfighterWrapped) return;\n\t\t\tfunction HackfighterAudioContext(...args) {\n\t\t\t\tconst ctx = new OriginalAudioContext(...args);\n\t\t\t\thackfighterAudioContexts.push(ctx);\n\t\t\t\treturn ctx;\n\t\t\t}\n\t\t\tHackfighterAudioContext.prototype = OriginalAudioContext.prototype;\n\t\t\tObject.setPrototypeOf(HackfighterAudioContext, OriginalAudioContext);\n\t\t\tHackfighterAudioContext.__hackfighterWrapped = true;\n\t\t\twindow[name] = HackfighterAudioContext;\n\t\t}\n\t\tfunction resumeHackfighterAudio() {\n\t\t\tfor (const ctx of hackfighterAudioContexts) {\n\t\t\t\tif (ctx && ctx.state === 'suspended') ctx.resume().catch(() => {});\n\t\t\t}\n\t\t}\n\t\tinstallHackfighterAudioUnlock('AudioContext');\n\t\tinstallHackfighterAudioUnlock('webkitAudioContext');\n\t\t['pointerdown', 'pointerup', 'click', 'touchend', 'keydown'].forEach((eventName) => {\n\t\t\twindow.addEventListener(eventName, resumeHackfighterAudio, { passive: true });\n\t\t});\n\n\t\tlet started = false;\n\t\tfunction launchGame() {\n\t\t\tif (started) return;\n\t\t\tstarted = true;\n\t\t\tstatusOverlay.style.cursor = 'default';\n\t\t\tsetStatusMode('progress');\n\t\t\tstartHackfighterGameAudioBridge();\n\t\t\tengine.startGame({\n\t\t\t\t'onProgress': function (current, total) {\n\t\t\t\t\tif (current > 0 && total > 0) {\n\t\t\t\t\t\tstatusProgress.value = current;\n\t\t\t\t\t\tstatusProgress.max = total;\n\t\t\t\t\t} else {\n\t\t\t\t\t\tstatusProgress.removeAttribute('value');\n\t\t\t\t\t\tstatusProgress.removeAttribute('max');\n\t\t\t\t\t}\n\t\t\t\t},\n\t\t\t}).then(() => {\n\t\t\t\tsetStatusMode('hidden');\n\t\t\t\tconst canvas = document.getElementById('canvas');\n\t\t\t\tif (canvas) canvas.focus();\n\t\t\t\tresumeHackfighterAudio();\n\t\t\t\tsetTimeout(resumeHackfighterAudio, 250);\n\t\t\t\tsetTimeout(resumeHackfighterAudio, 1000);\n\t\t\t}, displayFailureNotice);\n\t\t}\n\t\tstatusOverlay.addEventListener('pointerdown', launchGame, { once: true });\n\t\twindow.addEventListener('keydown', function (event) {\n\t\t\tif (event.key === 'Enter' || event.key === ' ') launchGame();\n\t\t}, { once: true });\n\t}\n}());'''
if old_tail not in text:
    raise SystemExit('Godot web template tail not found; export patch needs update')
text = text.replace(old_tail, new_tail)
text = text.replace('\t\tconst hackfighterAudioContexts = [];', '\t\twindow.hackfighterAudioContexts = window.hackfighterAudioContexts || [];\n\t\tconst hackfighterAudioContexts = window.hackfighterAudioContexts;')

bridge_json = json.dumps(bridge_urls, sort_keys=True)
bridge_js = f'''
\t\t// Low-level output bridge only. Sound timing still comes from Godot SoundManager.
\t\tconst hackfighterAudioBridgeUrls = {bridge_json};
\t\tlet hackfighterGameAudioBridge = null;
\t\tfunction startHackfighterGameAudioBridge() {{
\t\t\tif (hackfighterGameAudioBridge) return;
\t\t\tconst bank = {{}};
\t\t\tconst active = [];
\t\t\tfunction play(name, volume = 1.0) {{
\t\t\t\tconst url = hackfighterAudioBridgeUrls[name];
\t\t\t\tif (!url) return false;
\t\t\t\ttry {{
\t\t\t\t\tconst a = new Audio(url);
\t\t\t\t\ta.preload = 'auto';
\t\t\t\t\ta.volume = Math.max(0, Math.min(1, volume));
\t\t\t\t\ta.addEventListener('ended', () => {{ const i = active.indexOf(a); if (i >= 0) active.splice(i, 1); }}, {{ once: true }});
\t\t\t\t\tactive.push(a);
\t\t\t\t\tbank[name] = (bank[name] || 0) + 1;
\t\t\t\t\ta.play().catch(() => {{}});
\t\t\t\t\treturn true;
\t\t\t\t}} catch (e) {{ console.warn('Hackfighter audio bridge failed', name, e); return false; }}
\t\t\t}}
\t\t\thackfighterGameAudioBridge = {{ play, bank, active, urls: hackfighterAudioBridgeUrls }};
\t\t\twindow.hackfighterGameAudioBridge = hackfighterGameAudioBridge;
\t\t\twindow.hackfighterPlayGameSound = play;
\t\t}}
'''
text = text.replace('\n\t\tlet started = false;', '\n' + bridge_js + '\n\t\tlet started = false;')
p.write_text(text)
print(f'exported_and_patched_godot_triggered_audio_bridge {len(bridge_urls)} files')
PY
