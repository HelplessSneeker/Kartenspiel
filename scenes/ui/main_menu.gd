extends Control


func _on_start_button_pressed() -> void:
	# Der Sound ueberlebt den Szenenwechsel: Sfx ist ein Autoload und haengt
	# damit am Root, nicht an dieser Szene.
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_quit_button_pressed() -> void:
	Sfx.play("click")
	get_tree().quit()
