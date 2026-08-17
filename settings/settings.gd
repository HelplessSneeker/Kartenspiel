extends Node

## Einstellungen des Spielers: Lautstaerken und Vollbild. Autoload unter `Settings`.
##
## Zwei Aufgaben, die man auseinanderhalten sollte: den Wert *anwenden* (auf den
## AudioServer, auf das Fenster) und ihn *behalten* (Datei auf der Platte). Das
## Anwenden passiert sofort in den Settern - man dreht am Regler und hoert es.
## Gespeichert wird erst, wenn das Optionsfenster zugeht: eine Datei bei jedem
## Pixel Reglerbewegung neu zu schreiben waere Unsinn.
##
## ACHTUNG Autoload-Reihenfolge: dieses hier muss in project.godot **vor** `Sfx`
## stehen. Es legt den Audio-Bus "SFX" an, und `Sfx` haengt seine Player beim
## Start genau dort hinein - ein Bus, den es noch nicht gibt, waere ein Fehler
## in jedem Spielstart. Autoloads werden in der Reihenfolge der Liste geladen.

## Feuert nach jeder Aenderung. Das Optionsfenster stellt seine Regler danach.
signal changed

## Einstellungen gehoeren nach `user://`, nicht nach `res://`.
##
## `res://` ist im exportierten Spiel schreibgeschuetzt - es steckt in der
## PCK-Datei neben der ausfuehrbaren Datei. Im Editor faellt das nie auf, weil
## dort `res://` ein ganz normaler Ordner ist; kaputt ist es erst im Export.
## `user://` zeigt auf ein beschreibbares Verzeichnis des Betriebssystems
## (unter Windows im AppData-Zweig).
const FILE_PATH := "user://settings.cfg"

## Godots Standard-Bus heisst immer "Master" und existiert von sich aus.
const MASTER_BUS := "Master"
const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

var master_volume := 1.0:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_volume(MASTER_BUS, master_volume)
		changed.emit()

var sfx_volume := 1.0:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_volume(SFX_BUS, sfx_volume)
		changed.emit()

var music_volume := 0.7:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_volume(MUSIC_BUS, music_volume)
		changed.emit()

var fullscreen := false:
	set(value):
		fullscreen = value
		_apply_fullscreen(fullscreen)
		changed.emit()


func _ready() -> void:
	# Wie beim Sfx-Autoload: nicht mitpausieren, sonst waeren die Optionen aus
	# dem Pause-Menue heraus wirkungslos.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	load_settings()


# --- Laden und Speichern ------------------------------------------------------

## Liest die Datei, falls es sie gibt. Die Setter wenden die Werte dabei
## automatisch an - deshalb steht hier kein einziger apply()-Aufruf.
##
## Eine fehlende Datei ist kein Fehler, sondern der erste Start. Deshalb keine
## Warnung: eine Meldung, die bei jedem Neuinstallieren einmal auftaucht, bringt
## niemandem etwas ausser Misstrauen gegen Meldungen.
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(FILE_PATH) != OK:
		return
	master_volume = config.get_value("audio", "master", master_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)
	music_volume = config.get_value("audio", "music", music_volume)
	fullscreen = config.get_value("video", "fullscreen", fullscreen)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("video", "fullscreen", fullscreen)
	var err := config.save(FILE_PATH)
	if err != OK:
		push_warning("Einstellungen nicht speicherbar (%s): %d" % [FILE_PATH, err])


# --- Anwenden -----------------------------------------------------------------

## Legt einen Bus an, falls er fehlt.
##
## Der uebliche Weg dafuer ist das Audio-Panel im Editor, das eine
## `default_bus_layout.tres` schreibt. Ich kann den Editor nicht oeffnen und
## dieses Dateiformat nicht nachpruefen - im Code angelegt ist es dafuer
## selbstheilend: legst du die Busse spaeter im Editor richtig an, findet diese
## Funktion sie vor und tut nichts.
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	# Ohne send landet der Bus nirgends - der Master-Regler haette dann keine
	# Wirkung mehr auf das, was hier durchlaeuft.
	AudioServer.set_bus_send(idx, MASTER_BUS)


## `set_bus_volume_linear()` nimmt den Reglerwert direkt; die Umrechnung nach
## Dezibel passiert intern. Bei genau 0 wird zusaetzlich stummgeschaltet:
## linear 0 entspricht minus unendlich dB, und das ist als Zahl unangenehm.
func _apply_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, is_zero_approx(linear))
	AudioServer.set_bus_volume_linear(idx, linear)


func _apply_fullscreen(enabled: bool) -> void:
	var mode := (
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(mode)
