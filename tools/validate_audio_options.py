#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
sound = (root / "scripts/sound_manager.gd").read_text()

missing = []

for marker in [
    'const SFX_BUS_NAME := "SFX"',
    'const MUSIC_BUS_NAME := "Music"',
    'func _ensure_audio_buses() -> void:',
    'AudioServer.add_bus',
    'AudioServer.set_bus_name',
    'AudioServer.set_bus_volume_db',
    'player.bus = SFX_BUS_NAME',
    'var _music_player: AudioStreamPlayer = null',
    'func set_sfx_volume_percent(value: int) -> void:',
    'func set_music_volume_percent(value: int) -> void:',
    'func set_radio_channel(index: int) -> void:',
    'func get_radio_channel_label() -> String:',
]:
    if marker not in sound:
        missing.append(f"sound_manager missing {marker}")

for marker in [
    'var option_index: int = 0',
    'var option_sfx_volume: int = 60',
    'var option_music_volume: int = 70',
    'var option_radio_index: int = 0',
    'const OPTION_COUNT := 4',
    'SoundManager.set_sfx_volume_percent(option_sfx_volume)',
    'SoundManager.set_music_volume_percent(option_music_volume)',
    'SoundManager.set_radio_channel(option_radio_index)',
    'CPU PROFILE',
    'SFX BUS',
    'MUSIC BUS',
    'RADIO CHANNEL',
    'NO CHANNELS INSTALLED',
    'menu_body_label.position = Vector2(78, 94)',
    'menu_body_label.size = Vector2(356, 122)',
    'menu_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP',
    'menu_body_label.add_theme_font_size_override("font_size", 11)',
    'option_lines.append("%-4s %-14s %s"',
    'menu_body_label.text = "\\n".join(option_lines)',
    'option_index = posmod(option_index - 1, OPTION_COUNT)',
    'option_index = posmod(option_index + 1, OPTION_COUNT)',
    'func _adjust_option(delta: int) -> void:',
    'clampi(option_sfx_volume + delta * 5, 0, 100)',
    'clampi(option_music_volume + delta * 5, 0, 100)',
]:
    if marker not in main:
        missing.append(f"main missing {marker}")

# Require old single-option behavior to be gone from Options input.
old_options_block = '\t\tAppState.OPTIONS:\n\t\t\tif Input.is_action_just_pressed("p1_left"):\n\t\t\t\toption_difficulty_index = posmod(option_difficulty_index - 1, CPU_DIFFICULTIES.size())'
if old_options_block in main:
    missing.append("main still has old single difficulty-only options input")

if missing:
    raise SystemExit("\n".join(missing))
print("audio options validation passed")
