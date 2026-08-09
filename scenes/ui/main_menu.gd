extends Control


func _ready() -> void:
	%Options.closed.connect(_on_options_closed)


## Escape schliesst die Optionen. Ohne offene Optionen tut es hier nichts - im
## Hauptmenue gibt es nichts, wovon man zurueckkoennte. Dieselbe Regel wie im
## Pause-Menue: die Taste wird an einer Stelle je Bildschirm entschieden.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if %Options.visible:
		get_viewport().set_input_as_handled()
		%Options.close()


func _on_start_button_pressed() -> void:
	# Der Sound ueberlebt den Szenenwechsel: Sfx ist ein Autoload und haengt
	# damit am Root, nicht an dieser Szene.
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_options_button_pressed() -> void:
	Sfx.play("click")
	%Options.open()


func _on_credits_button_pressed() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")


func _on_quit_button_pressed() -> void:
	Sfx.play("click")
	get_tree().quit()


func _on_options_closed() -> void:
	%OptionsButton.grab_focus()
