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
if audio_dir.exists():
    shutil.rmtree(audio_dir)
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
    'menu_cursor': 'assets/audio/gameplay/0905/Menu_Open.wav',
    'menu_select': 'assets/audio/gameplay/0905/Menu_Select.wav',
    'menu_open': 'assets/audio/gameplay/0905/Menu_Open.wav',
    'light_attack': 'assets/audio/gameplay/0905/Light_Attack_Whiff.wav',
    'medium_attack': 'assets/audio/gameplay/0905/Medium_Attack_Whiff.wav',
    'hard_attack': 'assets/audio/gameplay/0905/Heavy_Attack_Whiff.wav',
    'special_teknium_1': 'assets/audio/specials/Teknium_Special_Fire_1.mp3',
    'special_teknium_2': 'assets/audio/specials/Teknium_Special_Fire_2.mp3',
    'special_lobster_1': 'assets/audio/specials/Lobster_Special_Fire_1.mp3',
    'special_lobster_2': 'assets/audio/specials/Lobster_Special_Fire_2.mp3',
    'jab_hit': 'assets/audio/gameplay/0905/Jab_Hit.wav',
    'fierce_hit': 'assets/audio/gameplay/0905/Fierce_Hit.wav',
    'short_hit': 'assets/audio/gameplay/0905/Short_Hit.wav',
    'roundhouse_hit': 'assets/audio/gameplay/0905/Fierce_Hit_2.wav',
    'blocked': 'assets/audio/gameplay/0905/Blocked.wav',
    'hit_ground': 'assets/audio/gameplay/0905/Hit_Ground.wav',
    'landing': 'assets/audio/gameplay/0905/Landing.wav',
    'grunt1': 'assets/audio/gameplay/0905/Male_Grunt_1.wav',
    'grunt2': 'assets/audio/gameplay/0905/Male_Grunt_2.wav',
    'ko_male': 'assets/audio/gameplay/0905/Male_General_Knockout.wav',
    'ko_lobster': 'assets/audio/gameplay/0905/Lobster_Knockout.wav',
    'ko_no_idea': 'assets/audio/gameplay/0905/No_Idea_Knockout.wav',
    'menu_theme': 'assets/audio/music/Hackfighter-Menu-Theme.ogg',
    'fight_theme_1': 'assets/audio/music/Hackfighter - PartOne.ogg',
    'fight_theme_2': 'assets/audio/music/Hackfighter - PartTwo.ogg',
    'fight_theme_3': 'assets/audio/music/Hackfighter - PartThree.ogg',
    'fight_theme_4': 'assets/audio/music/Hackfighter - PartFour.ogg',
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
\t\t\tlet music = null;
\t\t\tlet musicFadeTimer = null;
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
\t\t\tfunction playMusic(name, volume = 1.0, fadeSeconds = 0.0) {{
\t\t\t\tconst url = hackfighterAudioBridgeUrls[name];
\t\t\t\tif (!url) return false;
\t\t\t\ttry {{
\t\t\t\t\tstopMusic();
\t\t\t\t\tmusic = new Audio(url);
\t\t\t\t\tmusic.dataset.name = name;
\t\t\t\t\tmusic.loop = true;
\t\t\t\t\tmusic.preload = 'auto';
\t\t\t\t\tconst targetVolume = Math.max(0, Math.min(1, volume));
\t\t\t\t\tconst fadeMs = Math.max(0, fadeSeconds * 1000);
\t\t\t\t\tmusic.volume = fadeMs > 0 ? 0 : targetVolume;
\t\t\t\t\tmusic.play().catch(() => {{}});
\t\t\t\t\tif (fadeMs > 0) {{
\t\t\t\t\t\tconst startedAt = performance.now();
\t\t\t\t\t\tmusicFadeTimer = window.setInterval(() => {{
\t\t\t\t\t\t\tif (!music) return;
\t\t\t\t\t\t\tconst t = Math.min(1, (performance.now() - startedAt) / fadeMs);
\t\t\t\t\t\t\tmusic.volume = targetVolume * (1 - Math.pow(1 - t, 2));
\t\t\t\t\t\t\tif (t >= 1) {{ window.clearInterval(musicFadeTimer); musicFadeTimer = null; }}
\t\t\t\t\t\t}}, 50);
\t\t\t\t\t}}
\t\t\t\t\tbank[name] = (bank[name] || 0) + 1;
\t\t\t\t\treturn true;
\t\t\t\t}} catch (e) {{ console.warn('Hackfighter music bridge failed', name, e); return false; }}
\t\t\t}}
\t\t\tfunction stopMusic() {{
\t\t\t\tif (musicFadeTimer) {{ window.clearInterval(musicFadeTimer); musicFadeTimer = null; }}
\t\t\t\tif (music) {{ music.pause(); music.currentTime = 0; music = null; }}
\t\t\t}}
\t\t\thackfighterGameAudioBridge = {{ play, playMusic, stopMusic, bank, active, urls: hackfighterAudioBridgeUrls }};
\t\t\twindow.hackfighterGameAudioBridge = hackfighterGameAudioBridge;
\t\t\twindow.hackfighterPlayGameSound = play;
\t\t\twindow.hackfighterPlayGameMusic = playMusic;
\t\t\twindow.hackfighterStopGameMusic = stopMusic;
\t\t}}
'''
text = text.replace('\n\t\tlet started = false;', '\n' + bridge_js + '\n\t\tlet started = false;')
p.write_text(text)
print(f'exported_and_patched_godot_triggered_audio_bridge {len(bridge_urls)} files')
PY
