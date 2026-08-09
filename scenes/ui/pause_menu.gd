extends Control

## Pause-Menue. Liegt in game.tscn in einem eigenen CanvasLayer und haelt beim
## Oeffnen den ganzen Szenenbaum an.
##
## DER PUNKT, an dem Godot anders tickt als erwartet: `get_tree().paused = true`
## friert *alles* ein - auch dieses Menue. Ein pausiertes Menue nimmt keine
## Klicks an, und man kaeme nie wieder raus.
##
## Der Ausweg ist `process_mode` am Wurzelknoten dieser Szene (in der .tscn auf
## PROCESS_MODE_ALWAYS = 3). Die Kinder stehen auf INHERIT und erben das damit.
## Nicht WHEN_PAUSED, obwohl das zunaechst passender klingt: WHEN_PAUSED heisst
## *nur* waehrend der Pause - dann liefe _unhandled_input() im ungepausten Spiel
## gar nicht, und die Escape-Taste, die die Pause ueberhaupt erst ausloest, kaeme
## nie an.

## Platzhalter. Der Interface-Klick aus dem Kenney-Pack klang an dieser Stelle
## unangenehm - bis es einen eigenen Menuelaut gibt, tut es der Kartenlegeton.
##
## Bewusst eine Konstante und nicht viermal derselbe String: der Austausch soll
## eine Zeile sein, sobald der richtige Sound da ist. Vier verstreute Literale
## sind der Grund, warum Platzhalter Platzhalter bleiben.
const MENU_SFX := "card_play"


func _ready() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	# "ui_cancel" ist Godots eingebaute Aktion auf Escape - es braucht dafuer
	# keinen Eintrag in der Input-Map.
	if not event.is_action_pressed("ui_cancel"):
		return
	# Sonst reicht dasselbe Escape noch an andere weiter.
	get_viewport().set_input_as_handled()
	if visible:
		resume()
	else:
		open()


func open() -> void:
	Sfx.play(MENU_SFX)
	show()
	get_tree().paused = true


func resume() -> void:
	Sfx.play(MENU_SFX)
	get_tree().paused = false
	hide()


# --- Signale ------------------------------------------------------------------

func _on_resume_button_pressed() -> void:
	resume()


## Erst entpausieren, dann wechseln - in dieser Reihenfolge.
##
## `paused` haengt am SceneTree, nicht an der Szene. Die neue Szene landet also
## in einem noch pausierten Baum und steht sofort still, ohne dass es ein Menue
## gaebe, das sie wieder freigeben koennte.
func _on_restart_button_pressed() -> void:
	Sfx.play(MENU_SFX)
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_button_pressed() -> void:
	Sfx.play(MENU_SFX)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
