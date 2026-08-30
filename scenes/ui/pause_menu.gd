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


func _ready() -> void:
	hide()
	# Die Optionen haengen als letztes Kind unter diesem Knoten: dadurch liegen
	# sie ueber dem Pause-Dialog statt in ihm, und `%Options` bleibt trotzdem
	# aufloesbar - eindeutige Namen gelten nur innerhalb einer Szene.
	%Options.closed.connect(_on_options_closed)


## Escape hat hier drei Bedeutungen, und die Reihenfolge ist die Regel:
## Optionen offen -> Optionen zu. Sonst Pause offen -> weiterspielen. Sonst
## pausieren.
##
## Bewusst an *einer* Stelle entschieden. Liesse das Optionsfenster ebenfalls auf
## Escape lauschen, haetten zwei Knoten dieselbe Taste, und wer zuerst drankommt,
## haengt an der Baumreihenfolge - das ist keine Regel, das ist ein Zufall, der
## sich beim naechsten Umhaengen aendert.
func _unhandled_input(event: InputEvent) -> void:
	# "ui_cancel" ist Godots eingebaute Aktion auf Escape - es braucht dafuer
	# keinen Eintrag in der Input-Map.
	if not event.is_action_pressed("ui_cancel"):
		return
	# Sonst reicht dasselbe Escape noch an andere weiter.
	get_viewport().set_input_as_handled()
	if %Options.visible:
		%Options.close()
	elif visible:
		resume()
	else:
		open()


func _on_options_button_pressed() -> void:
	Sfx.play("click")
	%Options.open()


func open() -> void:
	Sfx.play("click")
	show()
	# Jetzt hat das Theme einen sichtbaren Fokus-Rahmen, also lohnt sich der
	# Griff danach: Enter fuehrt sofort zum naheliegenden Knopf, ohne Maus.
	%ResumeButton.grab_focus()
	get_tree().paused = true


func resume() -> void:
	Sfx.play("click")
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
	Sfx.play("click")
	get_tree().paused = false
	Fade.reload_scene()


func _on_menu_button_pressed() -> void:
	Sfx.play("click")
	get_tree().paused = false
	Fade.change_scene("res://scenes/ui/main_menu.tscn")


func _on_options_closed() -> void:
	%OptionsButton.grab_focus()
