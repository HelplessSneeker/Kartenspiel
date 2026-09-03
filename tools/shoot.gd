extends SceneTree

## Macht einen Screenshot einer Szene - auch von Zustaenden, die man sonst
## erspielen muesste.
##
## Warum es das gibt: ich (Ludicator) laufe auf einem Rechner ohne Bildschirm
## und habe das Spiel lange nie gesehen. Jede Optik-Aenderung war deshalb ein
## Draft, den bfn erst starten musste, um mir zu sagen, wie er aussieht. Mit
## dieser Datei hole ich mir das Bild selbst und pruefe Farben, Proportionen und
## Layout, bevor ich etwas abschicke.
##
## Was es *nicht* kann: Bewegung, Timing, Eingabe, Ton, Gefuehl. Ein Standbild
## sagt nicht, ob sich der Kartenflug richtig anfuehlt. Das bleibt bei bfn.
##
## Aufruf ueber tools/shoot.sh - siehe dort. Erstes Argument ist entweder ein
## Aufbau-Name aus SCENES oder direkt ein `res://...tscn`.
##
## `--headless` waere hier falsch: das ist ein Attrappen-Grafiktreiber fuer
## Export und CI, der gar nicht zeichnet - ein Screenshot davon ist schwarz.
## Gebraucht wird ein echter Bildschirm, und den stellt Xvfb.
##
## Dass das Projekt auf GL Compatibility laeuft, ist dafuer ein Gluecksfall:
## genau das rendert Mesas llvmpipe zuverlaessig in Software. Bei Forward+ waere
## der Weg deutlich wackliger.

## Wie viele Frames gewartet wird, bevor das Bild geholt wird.
##
## Nicht null und nicht eins: Szenen bauen ihr Layout ueber mehrere Frames auf
## (Container rechnen nach, `_fit_self()` in der Hand aendert die eigene Hoehe
## und loest damit ein zweites Layout aus), und Tweens brauchen Zeit. Bei zu
## wenigen Frames sieht man den Aufbau statt das Ergebnis.
const DEFAULT_FRAMES := 40

## Wie viele Frames zwischen Aufbau und Aufnahme zusaetzlich vergehen.
##
## Der Aufbau loest fast immer Bewegung aus - ein Overlay blendet ein, die Hand
## legt ab, eine Zahl steigt auf. Ohne diese Pause faengt man den Uebergang
## statt den Zustand.
const SETUP_FRAMES := 30

## Welcher Aufbau in welcher Szene stattfindet.
##
## Der Aufbau bestimmt die Szene und nicht umgekehrt: "belohnung" ist eine
## Aussage ueber den Zustand, und in welcher Datei der wohnt, muss der Aufrufer
## nicht wissen.
const SCENES := {
	"menu": "res://scenes/ui/main_menu.tscn",
	"optionen": "res://scenes/ui/main_menu.tscn",
	"credits": "res://scenes/ui/credits.tscn",
	"kampf": "res://scenes/game.tscn",
	"pause": "res://scenes/game.tscn",
	"ziehstapel": "res://scenes/game.tscn",
	"ablage": "res://scenes/game.tscn",
	"deck": "res://scenes/game.tscn",
	"belohnung": "res://scenes/game.tscn",
	"sieg": "res://scenes/game.tscn",
	"niederlage": "res://scenes/game.tscn",
	"hover": "res://scenes/game.tscn",
}

var _failed := false


func _initialize() -> void:
	# Verzoegert, weil zu diesem Zeitpunkt weder Wurzelfenster noch Autoloads
	# fertig sind. _initialize() laeuft, bevor der Baum steht.
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		_die("Aufruf: --script res://tools/shoot.gd ++ <aufbau|res://szene> <ziel.png> [frames]")
		return

	var target := args[0]
	var out_path := args[1]
	var frames := int(args[2]) if args.size() > 2 else DEFAULT_FRAMES

	var setup := ""
	var scene_path := target
	if not target.begins_with("res://"):
		if not SCENES.has(target):
			_die("Unbekannter Aufbau '%s'. Bekannt: %s" % [target, ", ".join(SCENES.keys())])
			return
		setup = target
		scene_path = SCENES[target]

	var packed := ResourceLoader.load(scene_path) as PackedScene
	if packed == null:
		_die("Szene nicht ladbar: %s" % scene_path)
		return

	# Manches muss passieren, *bevor* die Szene gebaut wird. Der Endbildschirm
	# des Runs braucht einen Run, der schon beim letzten Kampf steht - stellt
	# man das erst danach um, hat game.gd seinen Gegner und die Aufschrift
	# "Kampf 1/2" laengst aus dem alten Stand gelesen.
	if setup != "":
		_prepare(setup)
		if _failed:
			return

	var node := packed.instantiate()
	root.add_child(node)

	for i in frames:
		await process_frame

	if setup != "":
		await _apply_setup(setup, node)
		if _failed:
			return
		for i in SETUP_FRAMES:
			await process_frame

	# Der entscheidende Schritt. `get_image()` liest die Textur des Viewports
	# aus, und die ist erst nach dem Zeichnen gueltig - ohne dieses Warten
	# bekommt man ein leeres oder halb fertiges Bild zurueck.
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	if image == null:
		_die("Kein Bild vom Viewport bekommen.")
		return

	var error := image.save_png(out_path)
	if error != OK:
		_die("Konnte %s nicht schreiben (Fehler %d)." % [out_path, error])
		return

	print("SHOT %s%s -> %s (%dx%d)" % [
		scene_path, "" if setup == "" else " [%s]" % setup,
		out_path, image.get_width(), image.get_height(),
	])
	quit()


# --- Aufbauten ----------------------------------------------------------------

## Laeuft vor dem Bauen der Szene.
##
## Nur fuer Zustaende, die *vor* `_ready()` feststehen muessen. Alles andere
## gehoert nach _apply_setup(), wo man den fertigen Baum vor sich hat.
func _prepare(setup: String) -> void:
	if setup != "sieg":
		return

	# Der Autoload wird ueber den Baum geholt und nicht ueber seinen Namen: in
	# einem `--script`-Lauf gibt es die Autoloads zwar (sie haengen unter
	# /root/), ihre Namen sind aber keine Bezeichner zur Compile-Zeit. `Run`
	# direkt hinzuschreiben laesst das Skript gar nicht erst uebersetzen.
	var run := root.get_node_or_null("/root/Run")
	if run == null:
		_die("Autoload Run nicht gefunden.")
		return

	# Bis zum letzten Kampf vorruecken, dann baut game.gd von sich aus den
	# richtigen Gegner und die richtige Aufschrift.
	run.start_new()
	while run.fight_number() < run.fight_count():
		run.win_fight(run.health)

## Faehrt die Szene in den gewuenschten Zustand.
##
## GRUNDREGEL: so weit wie moeglich ueber die *echten* Wege des Spiels, nicht
## ueber Abkuerzungen. Fuer die Belohnung wird der Gegner totgeschlagen, nicht
## `_end_game()` aufgerufen - sonst zeigt der Screenshot einen Zustand, den das
## Spiel so nie erreicht, und genau darin versteckt sich der Fehler, den man
## finden wollte.
##
## Wo doch eine Methode direkt gerufen wird (die Stapel-Klicks), ist das der
## Signal-Empfaenger selbst - also die Zeile, die auch beim echten Klick liefe.
## Maus-Ereignisse einzuspeisen waere naeher am Original, haengt dafuer an
## Bildschirmkoordinaten und bricht beim naechsten Layout-Umbau lautlos.
##
## Jeder Aufbau bricht laut ab, wenn er seinen Knoten oder seine Methode nicht
## findet. Ein Werkzeug, das bei einer Umbenennung stillschweigend das falsche
## Bild liefert, ist schlimmer als keines.
func _apply_setup(setup: String, node: Node) -> void:
	match setup:
		# Szenen, die von sich aus schon der gesuchte Zustand sind. Sie stehen
		# trotzdem in SCENES, damit man sie beim Namen nennen kann statt den
		# Pfad zu tippen.
		"menu", "kampf", "credits":
			pass

		"optionen":
			_call(node.get_node_or_null("Options"), "open")

		"pause":
			_call(node.get_node_or_null("PauseLayer/PauseMenu"), "open")

		"ziehstapel":
			_call(node, "_on_deck_pile_clicked")

		"deck":
			_call(node, "_on_deck_button_pressed")

		"ablage":
			# Erst einen Zug beenden, sonst ist die Ablage leer und das Fenster
			# zeigt nur "Keine Karten drin" - richtig, aber nichts zum Ansehen.
			_call(node, "end_turn")
			await _wait(20)
			_call(node, "_on_discard_pile_clicked")

		"belohnung", "sieg", "niederlage":
			await _fight_outcome(setup, node)

		"hover":
			await _hover_first_card(node)

		_:
			_die("Aufbau '%s' steht in SCENES, hat aber keinen Ablauf." % setup)


## Kampfende herbeifuehren - ueber echten Schaden, nicht ueber _end_game().
##
## Genau toedlich und nicht mit einer grossen Zahl: die Anzeige laesst bei jedem
## Treffer die Schadenszahl aufsteigen, und ein "-99999" haengt dann quer im
## Bild. Der Endzustand ist derselbe, das Bild ist brauchbar.
##
## Wo der Run steht, hat fuer "sieg" schon _prepare() geregelt - hier faellt nur
## noch der letzte Gegner.
func _fight_outcome(setup: String, node: Node) -> void:
	if not _has(node, "player") or not _has(node, "enemy"):
		_die("game.tscn hat kein player/enemy mehr - Aufbau '%s' muss nachgezogen werden." % setup)
		return

	if setup == "niederlage":
		node.player.take_damage(node.player.health + node.player.block)
		return

	node.enemy.take_damage(node.enemy.health + node.enemy.block)
	await _wait(10)


## Erste Handkarte hervorheben - der Zustand, den man beim Ueberlegen sieht.
##
## Ueber die Signal-Empfaenger der Hand statt ueber echte Mausbewegung: wo eine
## Karte gerade liegt, haengt an Kartenzahl und Fenstergroesse, und ein
## Zielpunkt in Pixeln waere beim naechsten Layout-Umbau falsch.
func _hover_first_card(node: Node) -> void:
	var hand := node.get_node_or_null("Hand")
	if hand == null:
		_die("Kein Hand-Knoten in game.tscn.")
		return
	# Ueber das Signal erkannt statt ueber `is CardView`: globale Klassennamen
	# sind in einem `--script`-Lauf nicht verlaesslich vorhanden, und ein
	# Werkzeug soll nicht daran scheitern.
	var cards := hand.get_children().filter(func(c: Node) -> bool: return c.has_signal("clicked"))
	if cards.is_empty():
		_die("Keine Karten auf der Hand - zu frueh aufgenommen?")
		return
	_call(hand, "_on_card_mouse_entered", [cards[0]])
	await _wait(10)


# --- Kleinkram ----------------------------------------------------------------

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _has(node: Object, property: String) -> bool:
	return node != null and property in node


func _call(node: Object, method: String, args: Array = []) -> void:
	if node == null:
		_die("Knoten fuer '%s' nicht gefunden." % method)
		return
	if not node.has_method(method):
		_die("%s hat keine Methode '%s' (mehr?) - Aufbau muss nachgezogen werden." % [node, method])
		return
	node.callv(method, args)


func _die(message: String) -> void:
	_failed = true
	push_error(message)
	printerr("SHOOT-FEHLER: %s" % message)
	quit(1)
