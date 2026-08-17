extends Node

## Hintergrundmusik, als Autoload unter dem Namen `Music`.
##
## Dieselbe Idee wie bei `Sfx`: eine Szene sagt, welche *Stimmung* gilt -
## `Music.play("menu")` -, nicht welche Datei laufen soll. Was daraus wird,
## entscheidet diese Liste hier.
##
## Solange keine Musikdatei im Projekt liegt, bleibt alles still und funktioniert
## trotzdem. Das ist Absicht: das System steht, die Stuecke sucht bfn aus - ich
## kann nichts anhoeren und waere der falsche, der das entscheidet.

const TRACKS := {
	"menu": "res://assets/audio/music/menu.ogg",
	"battle": "res://assets/audio/music/battle.ogg",
}

## Dauer eines Uebergangs. Deutlich laenger als jede UI-Animation - Musik, die
## in 0,2 Sekunden umschaltet, klingt nach Fehler, nicht nach Wechsel.
const FADE_TIME := 1.2

## "Praktisch still". Nicht 0 linear, sondern eine Dezibelzahl weit unten:
## getweent wird `volume_db`, und minus unendlich laesst sich nicht animieren.
const SILENT_DB := -50.0

var _player: AudioStreamPlayer
var _tween: Tween

## Welches Stueck gerade gewollt ist. Der Vergleich damit ist der Grund, warum
## der Weg Hauptmenue -> Credits -> Hauptmenue die Musik nicht neu startet.
var _current := ""

## Schon gemeldete Fehlpfade. Ohne das kaeme bei jedem Szenenwechsel dieselbe
## Warnung erneut, und man gewoehnt sich an, Warnungen zu ueberlesen.
var _warned: Dictionary = {}


func _ready() -> void:
	# Musik laeuft in der Pause weiter - ein abreissender Soundtrack beim
	# Druecken von Escape waere unangenehmer als gar keiner.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = Settings.MUSIC_BUS
	add_child(_player)


## Wechselt auf ein Stueck. Laeuft es schon, passiert nichts.
func play(track_name: String) -> void:
	if track_name == _current:
		return
	if not TRACKS.has(track_name):
		push_warning("Unbekannte Musik: %s" % track_name)
		return

	var path: String = TRACKS[track_name]
	# Erst fragen, dann laden. `load()` auf einen Pfad, den es nicht gibt,
	# schreibt einen Ladefehler in die Konsole - und solange noch nicht jedes
	# Stueck im Projekt liegt, waere das bei jedem Szenenwechsel einer.
	if not ResourceLoader.exists(path):
		if not _warned.has(path):
			_warned[path] = true
			push_warning("Musikdatei fehlt (noch): %s" % path)
		# Wichtig: das vorige Stueck ausblenden, statt es weiterlaufen zu lassen.
		#
		# Vorher stand hier nur `return`, und weil damit auch `_current` stehen
		# blieb, spielte die Menuemusik einfach im Kampf weiter - es sah aus wie
		# ein Fehler im Szenenwechsel, war aber bloss die fehlende Datei. Stille
		# ist die ehrlichere Antwort: sie zeigt, dass hier etwas fehlt.
		stop()
		return

	var stream := load(path) as AudioStream
	if stream == null:
		return

	# Nahtlos wiederholen. Sonst steht das in den Import-Optionen der Datei -
	# dort vergisst man es, und das Stueck hoert nach zwei Minuten einfach auf.
	# Im Code gesetzt gilt es fuer jede Datei, die spaeter dazukommt.
	if "loop" in stream:
		stream.loop = true

	_current = track_name
	_crossfade(stream)


func stop() -> void:
	_current = ""
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", SILENT_DB, FADE_TIME * 0.5)
	_tween.tween_callback(_player.stop)


## Ausblenden, tauschen, einblenden - nacheinander, deshalb ohne set_parallel().
## Laeuft noch nichts, ueberspringt der erste Schritt sich selbst.
func _crossfade(stream: AudioStream) -> void:
	_kill_tween()
	_tween = create_tween()
	if _player.playing:
		_tween.tween_property(_player, "volume_db", SILENT_DB, FADE_TIME * 0.5)
	_tween.tween_callback(_start.bind(stream))
	_tween.tween_property(_player, "volume_db", 0.0, FADE_TIME * 0.5)


func _start(stream: AudioStream) -> void:
	_player.stream = stream
	_player.volume_db = SILENT_DB
	_player.play()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
