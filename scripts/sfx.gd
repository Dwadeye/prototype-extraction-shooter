extends Node

## Central sound player (autoload "Sfx"). Streams are preloaded WAVs made in
## assets/sfx (see gen_sfx.py in the asset workspace). Call from anywhere:
##   Sfx.play("shot_ar")
##   Sfx.play("step", -6.0, randf_range(0.9, 1.1))
## Looping bed (extraction hum): Sfx.start_loop("extract_hum") / Sfx.stop_loop()

const NAMES: Array[String] = [
	"shot_ar", "shot_pistol", "shot_sniper", "boom", "click", "reload",
	"swing", "throw", "hit_tick", "hurt", "pickup", "crate", "heal",
	"step", "wolf_growl", "boar_snort", "beast_die", "enemy_die",
	"extract_hum", "extract_done",
]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _loop_player: AudioStreamPlayer

func _ready() -> void:
	for name in NAMES:
		_streams[name] = load("res://assets/sfx/%s.wav" % name)
	for i in 4:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_loop_player = AudioStreamPlayer.new()
	add_child(_loop_player)

func play(stream_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(stream_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[0]
	for candidate in _players:
		if not candidate.playing:
			player = candidate
			break
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

func start_loop(stream_name: String, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(stream_name)
	if stream == null:
		return
	if _loop_player.stream == stream and _loop_player.playing:
		return
	_loop_player.stream = stream
	_loop_player.volume_db = volume_db
	_loop_player.play()

func stop_loop() -> void:
	_loop_player.stop()
