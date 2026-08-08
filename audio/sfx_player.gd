extends Node

## Zentrale Anlaufstelle fuer Soundeffekte, als Autoload unter dem Namen `Sfx`.
##
## Aufgerufen wird ueberall mit `Sfx.play("card_draw")`. Der Rest - welche Datei,
## wie viele Varianten, welcher Player gerade frei ist - bleibt hier drin. Der
## Spielcode soll sagen *was* passiert ist, nicht *wie* es klingt.

## Mehrere Dateien je Ereignis sind Absicht: hoert man beim Ziehen zehnmal
## exakt dieselbe Wellenform, klingt es nach Maschine. Eine zufaellige Variante
## kostet nichts und nimmt dem Sound die Monotonie.
const SFX_PATHS := {
	"card_draw": [
		"res://assets/audio/sfx/card-slide-1.ogg",
		"res://assets/audio/sfx/card-slide-2.ogg",
		"res://assets/audio/sfx/card-slide-3.ogg",
	],
	"card_play": [
		"res://assets/audio/sfx/card-place-1.ogg",
		"res://assets/audio/sfx/card-place-2.ogg",
		"res://assets/audio/sfx/card-place-3.ogg",
	],
	# Aktuell von niemandem gerufen - siehe _reshuffle_discard() in game.gd.
	"shuffle": ["res://assets/audio/sfx/card-shuffle.ogg"],
	"error": ["res://assets/audio/sfx/error_002.ogg"],
	"click": ["res://assets/audio/sfx/click_001.ogg"],
}

## Wie viele Sounds gleichzeitig laufen duerfen. Ein einzelner Player wuerde den
## laufenden Sound abschneiden, sobald der naechste kommt - und beim Zugende
## kommen Mischen und Ziehen dicht hintereinander.
const POOL_SIZE := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	_load_streams()
	_build_pool()


## Einmal beim Start laden statt per preload in der Konstanten: so faellt ein
## fehlender Pfad als Warnung auf, statt das ganze Skript am Parsen zu hindern.
func _load_streams() -> void:
	for key: String in SFX_PATHS:
		var loaded: Array[AudioStream] = []
		for path: String in SFX_PATHS[key]:
			var stream := load(path) as AudioStream
			if stream == null:
				push_warning("Sound nicht ladbar: %s" % path)
				continue
			loaded.append(stream)
		_streams[key] = loaded


func _build_pool() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Spielt ein Ereignis ab. Unbekannte Namen sind ein Tippfehler im Aufrufer und
## sollen auffallen, statt still nichts zu tun.
func play(sound_name: String) -> void:
	if not _streams.has(sound_name):
		push_warning("Unbekannter Sound: %s" % sound_name)
		return
	var variants: Array = _streams[sound_name]
	if variants.is_empty():
		return
	var player := _take_player()
	player.stream = variants[randi() % variants.size()]
	player.play()


## Reihum durch den Pool, ohne zu pruefen, ob der Player noch laeuft. Bei acht
## Playern ist der aelteste laengst fertig, bevor er wieder dran ist.
func _take_player() -> AudioStreamPlayer:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	return player
