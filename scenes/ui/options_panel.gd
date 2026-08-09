class_name OptionsPanel
extends Control

## Optionen als Overlay, nicht als eigene Szene.
##
## Das ist die eigentliche Entscheidung an diesem Stueck: waeren die Optionen
## eine Szene, muesste man zum Oeffnen `change_scene_to_file()` rufen - und
## damit den laufenden Kampf wegwerfen. Aus dem Pause-Menue heraus waere das
## absurd. Als Overlay funktioniert dasselbe Stueck an beiden Orten: im
## Hauptmenue und ueber dem pausierten Spiel.
##
## Wer es oeffnet und schliesst, entscheidet der Ort - deshalb `open()`/`close()`
## als Verben und ein `closed`-Signal, statt hier selbst auf Escape zu lauschen.
## Zwei Knoten, die beide auf Escape reagieren, streiten sich sonst darum, wer
## zuerst drankommt; siehe den Kommentar in pause_menu.gd.

signal closed


func _ready() -> void:
	hide()
	# Erst die Regler stellen, dann die Signale verbinden. Andersherum meldet
	# jedes `value = ...` sofort eine "Aenderung" zurueck und schreibt den
	# geladenen Wert mit dem Standardwert des Reglers ueber.
	%MasterSlider.value = Settings.master_volume
	%SfxSlider.value = Settings.sfx_volume
	%FullscreenButton.button_pressed = Settings.fullscreen

	%MasterSlider.value_changed.connect(_on_master_changed)
	%SfxSlider.value_changed.connect(_on_sfx_changed)
	%FullscreenButton.toggled.connect(_on_fullscreen_toggled)

	_refresh_labels()


func open() -> void:
	show()
	%BackButton.grab_focus()


## Gespeichert wird beim Schliessen, nicht bei jeder Reglerbewegung: eine Datei
## pro Mausbewegung neu zu schreiben waere Unfug. Angewendet ist der Wert
## laengst - das passiert sofort in den Settern von Settings.
func close() -> void:
	Settings.save_settings()
	hide()
	closed.emit()


func _refresh_labels() -> void:
	%MasterValue.text = "%d%%" % roundi(Settings.master_volume * 100.0)
	%SfxValue.text = "%d%%" % roundi(Settings.sfx_volume * 100.0)
	%FullscreenButton.text = "Vollbild: an" if Settings.fullscreen else "Vollbild: aus"


# --- Signale ------------------------------------------------------------------

func _on_master_changed(value: float) -> void:
	Settings.master_volume = value
	_refresh_labels()


func _on_sfx_changed(value: float) -> void:
	Settings.sfx_volume = value
	_refresh_labels()


func _on_fullscreen_toggled(pressed: bool) -> void:
	Settings.fullscreen = pressed
	_refresh_labels()


func _on_back_button_pressed() -> void:
	Sfx.play("click")
	close()
