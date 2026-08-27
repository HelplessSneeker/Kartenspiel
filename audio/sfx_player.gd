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

	# --- Kampfgeraeusche: Slots stehen, Dateien fehlen noch --------------------
	#
	# Dieselbe Abmachung wie bei der Musik: das System steht, die Toene sucht bfn
	# aus - ich kann nichts anhoeren und waere der falsche, der das entscheidet.
	# Fehlt eine Datei, bleibt es an der Stelle still, es warnt einmal beim
	# Start, und alles andere laeuft weiter.
	#
	# Ein Slot je Gegneraktion und nicht ein allgemeines "enemy_attack": in
	# einer Komoedie ist das Geraeusch die halbe Pointe, und ein Kind, das heult,
	# klingt nicht wie ein Kind, das sich ans Bein haengt. Welche Aktion welchen
	# Ton ruft, steht in ihrer .tres - hier steht nur, welche Datei dahinter liegt.
	"heulen": ["res://assets/audio/sfx/heulen.ogg"],
	"bein": ["res://assets/audio/sfx/bein.ogg"],
	"mama": ["res://assets/audio/sfx/mama.ogg"],
	"schmollen": ["res://assets/audio/sfx/schmollen.ogg"],

	# --- Kartengeraeusche -----------------------------------------------------
	#
	# PLATZHALTER, ungehoert ausgesucht. Ich habe auf primus kein Audio - die
	# Auswahl lief ueber Titel, Lizenz und Laenge, nicht ueber den Klang. Beides
	# gehoert gegengehoert und faellt vermutlich wieder raus.
	#
	# Zwei Watschn-Varianten aus demselben Grund wie beim Ziehen: der Schlag
	# kommt oft, und zweimal exakt dieselbe Wellenform klingt nach Knopfdruck
	# statt nach Ohrfeige.
	"watschn": [
		"res://assets/audio/sfx/watschn-1.ogg",
		"res://assets/audio/sfx/watschn-2.ogg",
	],
	"bier": ["res://assets/audio/sfx/bier.ogg"],
}

## Feineinstellung je Ereignis, in Dezibel. Was hier nicht steht, laeuft mit 0 -
## also die Datei so, wie sie ist.
##
## Noetig, weil die Toene aus verschiedenen Quellen stammen und verschieden laut
## ausgesteuert sind. Die Kenney-Sounds sind aufeinander abgestimmt, die
## Freesound-Dateien sind es weder untereinander noch mit denen.
##
## Das ist etwas anderes als der SFX-Regler in den Optionen: der gilt fuer alles
## zusammen und gehoert dem Spieler. Das hier gleicht *eine Datei* gegen die
## anderen aus und gehoert ins Projekt - sonst muesste der Spieler mit seinem
## Regler ausbaden, dass zwei Dateien unterschiedlich laut aufgenommen wurden.
##
## Ungehoert gewaehlt (Befund bfn "Karteneffekte zu leise", 27.08.2026). Knackst
## oder scheppert es, ist die Zahl zu hoch - dann runter statt Datei tauschen.
const SFX_GAIN_DB := {
	"watschn": 5.0,
	"bier": 5.0,
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
##
## Erst fragen, dann laden - dieselbe Regel wie im Music-Autoload. `load()` auf
## einen Pfad, den es nicht gibt, schreibt einen harten Ladefehler in die
## Konsole, und solange noch nicht jeder Ton im Projekt liegt, waere das ein
## Schwall roter Zeilen bei jedem Start. Die Warnung hier kommt genau einmal
## beim Hochfahren und liest sich als das, was sie ist: eine Liste dessen, was
## noch fehlt.
func _load_streams() -> void:
	for key: String in SFX_PATHS:
		var loaded: Array[AudioStream] = []
		for path: String in SFX_PATHS[key]:
			if not ResourceLoader.exists(path):
				push_warning("Soundeffekt fehlt (noch): %s" % path)
				continue
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
	# Jedes Mal setzen, nicht nur wenn ein Gain eingetragen ist: die Player werden
	# reihum wiederverwendet, und ohne das Zuruecksetzen liefe der naechste Ton
	# mit der Verstaerkung des vorigen.
	player.volume_db = SFX_GAIN_DB.get(sound_name, 0.0)
	player.play()


## Reihum durch den Pool, ohne zu pruefen, ob der Player noch laeuft. Bei acht
## Playern ist der aelteste laengst fertig, bevor er wieder dran ist.
func _take_player() -> AudioStreamPlayer:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	return player
