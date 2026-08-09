extends Control

## Credits-Screen.
##
## Kein Schmuck, sondern eine Lizenzpflicht: die vier Icons stehen unter
## CC BY 3.0, und Namensnennung heisst dort *im Spiel*, nicht nur in einer
## Datei im Repository. Die Schriften (OFL) und die Kenney-Sounds (CC0)
## verlangen es nicht, stehen aber mit drin - wer einmal hinsieht, soll alles
## sehen. Der Wortlaut kommt aus ASSETS.md; aendert sich dort etwas, gehoert es
## auch hierher.


func _ready() -> void:
	# Die URLs im Text sind BBCode-Links. Godot klickt sie nicht selbst an - es
	# meldet nur, dass eine Meta angeklickt wurde, und was dann passiert,
	# entscheidet das Spiel. Deshalb diese Verbindung.
	%Text.meta_clicked.connect(_on_meta_clicked)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _on_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


func _on_back_button_pressed() -> void:
	_back()


func _back() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
