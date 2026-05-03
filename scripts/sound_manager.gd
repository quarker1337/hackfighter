extends Node

## SoundManager — central audio manifest, SFX/Music buses, and playback pool.
## Announcer, fight SFX, and character vocals route through the SFX bus.
## Music/radio support is wired now; channels can be populated later.

# ── Audio bus names ────────────────────────────────────────────────────
const SFX_BUS_NAME := "SFX"
const MUSIC_BUS_NAME := "Music"
const DEFAULT_SFX_VOLUME_PERCENT := 60
const DEFAULT_MUSIC_VOLUME_PERCENT := 70

# ── Sound manifest ─────────────────────────────────────────────────────
const MANIFEST: Dictionary = {
	"fight":        "res://assets/audio/announcer/Fight.mp3",
	"fight_alt":    "res://assets/audio/announcer/Fight_2.mp3",
	"ready":        "res://assets/audio/announcer/Ready.mp3",
	"round_one":    "res://assets/audio/announcer/Round_One.mp3",
	"round_two":    "res://assets/audio/announcer/Round_Two.mp3",
	"round_three":  "res://assets/audio/announcer/Round_Three.mp3",
	"p1_wins":      "res://assets/audio/announcer/PlayerOne_Wins.mp3",
	"p2_wins":      "res://assets/audio/announcer/PlayerTwo_Wins.mp3",
	"draw":         "res://assets/audio/announcer/Draw.mp3",
	"you_win":      "res://assets/audio/announcer/You_Win.mp3",
	"you_lose":     "res://assets/audio/announcer/You_Loose.mp3",
	"perfect":      "res://assets/audio/announcer/Perfect.mp3",
	"menu_theme":   "res://assets/audio/01 Select Screen & World Map/REMOVED_AUDIO_01 - Mode Select.wav",
	"menu_cursor":  "res://assets/audio/01 Select Screen & World Map/REMOVED_AUDIO_02 - Move Cursor.wav",
	"menu_select":  "res://assets/audio/01 Select Screen & World Map/REMOVED_AUDIO_03 - Selection.wav",
	"menu_open":    "res://assets/audio/01 Select Screen & World Map/REMOVED_AUDIO_04 - Plane.wav",
	"light_attack": "res://assets/audio/04 Moves & Hits/REMOVED_AUDIO_38 - Light Attack.wav",
	"medium_attack":"res://assets/audio/04 Moves & Hits/REMOVED_AUDIO_39 - Medium Attack.wav",
	"hard_attack":  "res://assets/audio/04 Moves & Hits/REMOVED_AUDIO_40 - Hard Attack1.wav",
	"jab_hit":      "res://assets/audio/04 Moves & Hits/REMOVED_AUDIO_42 - Jab Hit.wav",
	"fierce_hit":   "res://assets/audio/04 Moves & Hits/REMOVED_AUDIO_44 - Fierce Hit.wav",
	"short_hit":    "res://assets/audio/04 Moves & Hits/REMOVED_AUDIO_45 - Short Hit.wav",
	"roundhouse_hit":"res://assets/audio/04 Moves & Hits/REMOVED_AUDIO_47 - Roundhouse Hit.wav",
	"blocked":      "res://assets/audio/04 Moves & Hits/REMOVED_AUDIO_51 - Blocked.wav",
	"hit_ground":   "res://assets/audio/04 Moves & Hits/REMOVED_AUDIO_52 - Hit the ground.wav",
	"landing":      "res://assets/audio/04 Moves & Hits/REMOVED_AUDIO_53 - Landing.wav",
	"grunt1":       "res://assets/audio/05 Character Voices/REMOVED_AUDIO_63 - Grunt1.wav",
	"grunt2":       "res://assets/audio/05 Character Voices/REMOVED_AUDIO_64 - Grunt2.wav",
	"ko_male":      "res://assets/audio/05 Character Voices/REMOVED_AUDIO_67 - KO Male.wav",
}

# Empty for now; add future songs here as {"label": "NAME", "path": "res://..."}.
const RADIO_CHANNELS: Array[Dictionary] = []

# ── Loaded audio streams ────────────────────────────────────────────────
var _streams: Dictionary = {}

# ── Player pool for overlapping playback ────────────────────────────────
var _players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS: int = 8
var _music_player: AudioStreamPlayer = null
var _sfx_volume_percent: int = DEFAULT_SFX_VOLUME_PERCENT
var _music_volume_percent: int = DEFAULT_MUSIC_VOLUME_PERCENT
var _radio_channel_index: int = 0

func _ready() -> void:
	_ensure_audio_buses()
	# Create player pool for overlapping SFX/announcer/vocal playback.
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS_NAME
		add_child(player)
		_players.append(player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS_NAME
	add_child(_music_player)
	set_sfx_volume_percent(DEFAULT_SFX_VOLUME_PERCENT)
	set_music_volume_percent(DEFAULT_MUSIC_VOLUME_PERCENT)
	set_radio_channel(0)

	# Pre-load all sounds from manifest.
	_load_sounds()

func _ensure_audio_buses() -> void:
	_ensure_named_bus(SFX_BUS_NAME)
	_ensure_named_bus(MUSIC_BUS_NAME)

func _ensure_named_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus(AudioServer.get_bus_count())
	var idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func _load_sounds() -> void:
	var loaded: int = 0
	var failed: int = 0
	for name in MANIFEST:
		var path: String = MANIFEST[name]
		var stream := load(path) as AudioStream
		if stream:
			_streams[name] = stream
			loaded += 1
		else:
			push_warning("SoundManager: FAILED to load '%s' from %s" % [name, path])
			failed += 1
	print("SoundManager: loaded %d/%d sounds (%d failed)" % [loaded, MANIFEST.size(), failed])

## Play a sound by logical name. Volume 0.0–1.0 before SFX bus attenuation.
func play(name: String, volume: float = 1.0) -> void:
	if not _streams.has(name):
		return
	_play_stream(_streams[name], volume)

## Play the current Hackfighter announcer round call.
func play_round_call(round_number: int, volume: float = 0.75) -> void:
	match round_number:
		1:
			play("round_one", volume)
		2:
			play("round_two", volume)
		_:
			play("round_three", volume)

## Play the match-result announcer by winner slot.
func play_match_result(winner: int, volume: float = 0.75) -> void:
	match winner:
		1:
			play("p1_wins", volume)
		2:
			play("p2_wins", volume)
		_:
			play("draw", volume)

func set_sfx_volume_percent(value: int) -> void:
	_sfx_volume_percent = clampi(value, 0, 100)
	_set_bus_volume_percent(SFX_BUS_NAME, _sfx_volume_percent)

func set_music_volume_percent(value: int) -> void:
	_music_volume_percent = clampi(value, 0, 100)
	_set_bus_volume_percent(MUSIC_BUS_NAME, _music_volume_percent)

func get_sfx_volume_percent() -> int:
	return _sfx_volume_percent

func get_music_volume_percent() -> int:
	return _music_volume_percent

func get_radio_channel_count() -> int:
	return RADIO_CHANNELS.size()

func set_radio_channel(index: int) -> void:
	_radio_channel_index = 0
	if RADIO_CHANNELS.is_empty():
		if _music_player:
			_music_player.stop()
		return
	_radio_channel_index = posmod(index, RADIO_CHANNELS.size())
	var channel: Dictionary = RADIO_CHANNELS[_radio_channel_index]
	var stream := load(channel.get("path", "")) as AudioStream
	if stream and _music_player:
		_music_player.stream = stream
		_music_player.play()

func get_radio_channel_label() -> String:
	if RADIO_CHANNELS.is_empty():
		return "NO CHANNELS INSTALLED"
	return String(RADIO_CHANNELS[_radio_channel_index].get("label", "CHANNEL %02d" % [_radio_channel_index + 1]))

func play_music(name: String, volume: float = 0.7) -> void:
	if not _music_player or not _streams.has(name):
		return
	if _music_player.stream == _streams[name] and _music_player.playing:
		return
	_music_player.stream = _streams[name]
	_music_player.bus = MUSIC_BUS_NAME
	_music_player.volume_db = linear_to_db(clampf(volume, 0.0, 1.0))
	_music_player.play()

func stop_music() -> void:
	if _music_player:
		_music_player.stop()

func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing

func _set_bus_volume_percent(bus_name: String, value: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if value <= 0:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(float(value) / 100.0))

## Play a raw AudioStream with given volume.
func _play_stream(stream: AudioStream, volume: float) -> void:
	# Find an idle player from the pool.
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.bus = SFX_BUS_NAME
			player.volume_db = linear_to_db(volume)
			player.play()
			return
	# All busy — steal the first one (oldest).
	var player := _players[0]
	player.stream = stream
	player.bus = SFX_BUS_NAME
	player.volume_db = linear_to_db(volume)
	player.play()

## Attack swing sound — matches JS: punches play light_attack, kicks play medium_attack.
func play_attack_swing(attack_name: String) -> void:
	if attack_name == "specialAttack":
		play("hard_attack", 0.75)
	elif attack_name == "lightPunch" or attack_name == "heavyPunch":
		play("light_attack", 0.6)
	else:
		play("medium_attack", 0.6)

## Hit connect sound — matches JS hitSounds mapping.
func play_hit_sound(attack_name: String) -> void:
	var hit_sounds: Dictionary = {
		"lightPunch": "jab_hit",
		"heavyPunch": "fierce_hit",
		"lightKick":  "short_hit",
		"heavyKick":  "roundhouse_hit",
		"specialAttack": "fierce_hit",
	}
	if hit_sounds.has(attack_name):
		play(hit_sounds[attack_name], 0.8)
	# Also play a random grunt.
	play("grunt1" if randi() % 2 == 0 else "grunt2", 0.6)

## Blocked hit sound.
func play_block_sound() -> void:
	play("blocked", 0.7)

## Landing sound.
func play_landing() -> void:
	play("landing", 0.5)

## KO sound.
func play_ko() -> void:
	play("ko_male", 0.8)

## Hit the ground (knockdown).
func play_hit_ground() -> void:
	play("hit_ground", 0.6)
