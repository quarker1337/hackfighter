extends Node

## SoundManager — 1:1 port of JS audio.js
## Loads WAV files from the JS audio manifest and plays them on demand.
## Uses a pool of AudioStreamPlayer nodes to allow overlapping sounds.

# ── Sound manifest (matching JS audio.js exactly) ──────────────────────
const MANIFEST: Dictionary = {
	"fight":        "res://assets/audio/02 Fight Announcer/REMOVED_AUDIO_17 - Fight!.wav",
	"round":        "res://assets/audio/02 Fight Announcer/REMOVED_AUDIO_18 - Round.wav",
	"one":          "res://assets/audio/02 Fight Announcer/REMOVED_AUDIO_19 - One.wav",
	"two":          "res://assets/audio/02 Fight Announcer/REMOVED_AUDIO_20 - Two.wav",
	"three":        "res://assets/audio/02 Fight Announcer/REMOVED_AUDIO_22 - Three.wav",
	"final":        "res://assets/audio/02 Fight Announcer/REMOVED_AUDIO_21 - Final.wav",
	"you_win":      "res://assets/audio/02 Fight Announcer/REMOVED_AUDIO_14 - You win!.wav",
	"you_lose":     "res://assets/audio/02 Fight Announcer/REMOVED_AUDIO_15 - You lose.wav",
	"perfect":      "res://assets/audio/02 Fight Announcer/REMOVED_AUDIO_16 - Perfect.wav",
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

# ── Loaded audio streams ────────────────────────────────────────────────
var _streams: Dictionary = {}

# ── Player pool for overlapping playback ────────────────────────────────
var _players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS: int = 8

func _ready() -> void:
	# Create player pool
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	
	# Pre-load all sounds from manifest
	_load_sounds()

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

## Play a sound by logical name. Volume 0.0–1.0.
func play(name: String, volume: float = 1.0) -> void:
	if not _streams.has(name):
		return
	_play_stream(_streams[name], volume)

## Play a raw AudioStream with given volume.
func _play_stream(stream: AudioStream, volume: float) -> void:
	# Find an idle player from the pool
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(volume)
			player.play()
			return
	# All busy — steal the first one (oldest)
	var player := _players[0]
	player.stream = stream
	player.volume_db = linear_to_db(volume)
	player.play()

## Attack swing sound — matches JS: punches play light_attack, kicks play medium_attack
func play_attack_swing(attack_name: String) -> void:
	if attack_name == "lightPunch" or attack_name == "heavyPunch":
		play("light_attack", 0.6)
	else:
		play("medium_attack", 0.6)

## Hit connect sound — matches JS hitSounds mapping
func play_hit_sound(attack_name: String) -> void:
	var hit_sounds: Dictionary = {
		"lightPunch": "jab_hit",
		"heavyPunch": "fierce_hit",
		"lightKick":  "short_hit",
		"heavyKick":  "roundhouse_hit",
	}
	if hit_sounds.has(attack_name):
		play(hit_sounds[attack_name], 0.8)
	# Also play a random grunt
	play("grunt1" if randi() % 2 == 0 else "grunt2", 0.6)

## Blocked hit sound
func play_block_sound() -> void:
	play("blocked", 0.7)

## Landing sound
func play_landing() -> void:
	play("landing", 0.5)

## KO sound
func play_ko() -> void:
	play("ko_male", 0.8)

## Hit the ground (knockdown)
func play_hit_ground() -> void:
	play("hit_ground", 0.6)
