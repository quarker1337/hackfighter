#!/usr/bin/env python3
from pathlib import Path
import struct
import sys

root = Path(__file__).resolve().parents[1]

def png_size(path: Path):
    data = path.read_bytes()[:24]
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    return struct.unpack('>II', data[16:24])

checks = [
    root / 'scenes' / 'HealthBar.tscn',
    root / 'scripts' / 'health_bar.gd',
    root / 'shaders' / 'healthbar_fill.gdshader',
    root / 'shaders' / 'chamfer_mask.gdshader',
    root / 'assets' / 'ui' / 'healthbar_track.png',
    root / 'assets' / 'ui' / 'healthbar_outline.png',
    root / 'assets' / 'ui' / 'portrait_ring.png',
    root / 'assets' / 'ui' / 'hero_profile.png',
    root / 'assets' / 'ui' / 'timer_frame.png',
    root / 'art' / 'portraits' / 'teknium_portrait.png',
    root / 'art' / 'portraits' / 'lobster_portrait.png',
    root / 'art' / 'portraits' / 'nousgirl_portrait.png',
]
missing = [str(p.relative_to(root)) for p in checks if not p.exists()]

main = (root / 'scripts' / 'main.gd').read_text()
health = (root / 'scripts' / 'health_bar.gd').read_text()
scene = (root / 'scenes' / 'HealthBar.tscn').read_text() if (root / 'scenes' / 'HealthBar.tscn').exists() else ''
shader = (root / 'shaders' / 'healthbar_fill.gdshader').read_text() if (root / 'shaders' / 'healthbar_fill.gdshader').exists() else ''
main_scene = (root / 'scenes' / 'Main.tscn').read_text() if (root / 'scenes' / 'Main.tscn').exists() else ''
project = (root / 'project.godot').read_text() if (root / 'project.godot').exists() else ''

required_main = [
    'const HEALTH_BAR_SCENE',
    'p1_health_widget',
    'p2_health_widget',
    'timer_word_label.text = "TIME"',
    'timer_frame.png',
    'Vector2(8, 4)',
    'Vector2(292, 4)',
    'CanvasLayer.new()',
    'hud_root.add_child(node)',
    'game_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST',
]
missing_main = [s for s in required_main if s not in main]

required_health = [
    '"%s — %s"',
    '#3FF6E0', '#FF4FA8', '#7CF7B5', '#FFC2E0',
    '"LOBSTER"', '"NOUSGIRL"', '"TEKNIUM"',
    'healthbar_fill.gdshader',
    'BAR_HEIGHT: float = 27.0', 'PORTRAIT_WIDTH: float = 54.0', 'PORTRAIT_HEIGHT: float = 54.0',
    'FILL_INSET_X: float = 4.0',
    'fill_clip.size.x', 'tween_property(fill_clip, "size:x"',
    'target_x = FILL_INSET_X + (_full_width - target_w)',
    'STRETCH_KEEP_ASPECT_COVERED', 'portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR',
    'teknium_portrait.png', 'lobster_portrait.png', 'nousgirl_portrait.png',
    'fill.texture = track.texture',
    'hero_profile.png',
    'fill.position.x = -(_full_width - target_w) if slot != "P1" else 0.0',
    'damage_flash', 'TEXTURE_FILTER_LINEAR',
]
missing_health = [s for s in required_health if s not in health]

required_scene = [
    '[node name="Portrait" type="TextureRect"',
    '[node name="PortraitRing" type="TextureRect"',
    '[node name="NameLabel" type="Label"',
    '[node name="Fill" type="NinePatchRect"',
    'patch_margin_left = 8',
    'z_index = 2',
    'offset_top = 1.0',
    'offset_bottom = 57.0',
    'stretch_mode = 6',
]
missing_scene = [s for s in required_scene if s not in scene]

shader_required = ['base_color', 'shine_color', 'shine_pos', 'shine_width', 'scan_strength', 'TIME', 'drift', 'damage_flash', 'texture(TEXTURE, UV)', 'COLOR = vec4(col, mask)']
missing_shader = [s for s in shader_required if s not in shader]

forbidden_present = []
forbidden_anywhere = [
    'p1_health_label.text = "P1:',
    'p2_health_label.text = "P2:',
    'p1_name_label.text = "OLD_PROTOTYPE_FIGHTER"',
    'p2_name_label.text = "OLD_PROTOTYPE_FIGHTER"',
    'PREMIUM', '.EXE', 'PRT',
    'bar.scale.x = -1.0',
    'Color.YELLOW',
    'SuperMeter', 'Pip', 'Indicator', 'Placeholder',
]
for s in forbidden_anywhere:
    if s in main + health + scene:
        forbidden_present.append(s)
# HealthBar scene specifically must not have yellow/pip-like ColorRects besides Fill.
if 'Color(1, 1, 0' in scene or 'FFFF00' in scene or 'FFEC27' in scene:
    forbidden_present.append('yellow square color in HealthBar.tscn')

bad_sizes = []
expected_sizes = {
    'assets/ui/healthbar_track.png': (164, 27),
    'assets/ui/healthbar_outline.png': (164, 27),
    'assets/ui/portrait_ring.png': (224, 160),
    'assets/ui/hero_profile.png': (75, 75),
    'assets/ui/timer_frame.png': (72, 56),
    'art/portraits/teknium_portrait.png': (192, 192),
    'art/portraits/lobster_portrait.png': (192, 192),
    'art/portraits/nousgirl_portrait.png': (192, 192),
}
for rel, expected in expected_sizes.items():
    path = root / rel
    if path.exists() and png_size(path) != expected:
        bad_sizes.append(f'{rel}: {png_size(path)} != {expected}')

font_ok = any((root / 'fonts').glob('*.ttf'))
world_env_ok = 'WorldEnvironment' in main_scene and 'glow_enabled = true' in main_scene
hit_hook_ok = '.take_damage(' in main
round_pips_removed = 'Color.YELLOW' not in main and 'p1_dot := ColorRect.new()' not in main and 'p2_dot := ColorRect.new()' not in main
round4_native_hud_ok = 'window/stretch/mode="canvas_items"' in project and 'CanvasLayer.new()' in main and 'hud_root.add_child(node)' in main and '_layout_native_layers' not in main and 'game_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST' in main

failures = []
if missing: failures.append('missing files: ' + ', '.join(missing))
if missing_main: failures.append('missing main snippets: ' + ', '.join(missing_main))
if missing_health: failures.append('missing healthbar snippets: ' + ', '.join(missing_health))
if missing_scene: failures.append('missing scene snippets: ' + ', '.join(missing_scene))
if missing_shader: failures.append('missing shader snippets: ' + ', '.join(missing_shader))
if forbidden_present: failures.append('forbidden snippets: ' + ', '.join(forbidden_present))
if bad_sizes: failures.append('bad PNG sizes: ' + '; '.join(bad_sizes))
if not font_ok: failures.append('missing fonts/*.ttf')
if not world_env_ok: failures.append('missing WorldEnvironment glow in Main.tscn')
if not hit_hook_ok: failures.append('main.gd does not call HealthBar.take_damage()')
if not round_pips_removed: failures.append('round-win pips/yellow square artifacts still present near HUD')
if not round4_native_hud_ok: failures.append('round4 native HUD layer/stretch fix missing')

if failures:
    print('healthbar spec validation FAILED')
    for failure in failures:
        print(failure)
    sys.exit(1)

print('healthbar spec validation passed')
