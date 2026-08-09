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
		"res://assets/audio/sfx/card-place-3.ogg",
	],
	# Aktuell von niemandem gerufen - siehe _reshuffle_discard() in game.gd.
	"shuffle": ["res://assets/audio/sfx/card-shuffle.ogg"],
	"error": ["res://assets/audio/sfx/error_002.ogg"],
	# Platzhalter: der Interface-Klick klang im Menue unangenehm (Befund bfn,
	# 09.08.2026). Bis ein eigener Menuelaut da ist, nimmt der Klick den
	# Kartenlegeton.
	#
	# Getauscht wird hier und nicht bei den Aufrufern. Die sagen weiterhin
	# Sfx.play("click"), also *was* passiert ist - welche Datei dabei laeuft, ist
	# genau die Entscheidung, die dieses Autoload besitzt. Sonst haette der
	# Tausch acht Stellen in fuenf Dateien beruehrt und je nachdem, welche man
	# vergisst, klaenge das Menue an zwei Orten verschieden.
	#
	# Das Original liegt weiter unter assets/audio/sfx/click_001.ogg.
	"click": [
		"res://assets/audio/sfx/card-place-2.ogg",
	],
}

## Wie viele Sounds gleichzeitig laufen duerfen. Ein einzelner Player wuerde den
## laufenden Sound abschneiden, sobald der naechste kommt - und beim Zugende
## kommen Mischen und Ziehen dicht hintereinander.
const POOL_SIZE := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	# Autoloads haengen unter dem Wurzelknoten und erben dessen Prozess-Modus -
	# und der ist PAUSABLE. Ohne diese Zeile schweigt das Pause-Menue: sein
	# Klick geht zwar raus, aber die AudioStreamPlayer hier stehen still,
	# solange get_tree().paused gilt. Ein Ton, der nur ausserhalb der Pause
	# kommt, ist genau dort kaputt, wo man ihn zur Rueckmeldung braucht.
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		# Alle Effekte auf den SFX-Bus, sonst greift der Effekte-Regler ins
		# Leere und es gaebe nur noch Gesamtlautstaerke. Den Bus legt das
		# Settings-Autoload an - deshalb steht es in project.godot vor diesem.
		player.bus = Settings.SFX_BUS
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
