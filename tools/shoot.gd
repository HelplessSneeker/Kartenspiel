extends SceneTree

## Macht einen Screenshot einer Szene, ohne dass jemand zusieht.
##
## Warum es das gibt: ich (Ludicator) laufe auf einem Rechner ohne Bildschirm
## und habe das Spiel nie gesehen. Jede Optik-Aenderung war deshalb ein Draft,
## den bfn erst starten musste, um mir zu sagen, wie er aussieht. Mit dieser
## Datei kann ich mir das Bild selbst holen und Farben, Proportionen und Layout
## pruefen, bevor ich etwas abschicke.
##
## Was es *nicht* kann: Bewegung, Timing, Eingabe, Ton, Gefuehl. Ein Standbild
## sagt nicht, ob sich der Kartenflug richtig anfuehlt. Das bleibt bei bfn.
##
## Aufruf (Xvfb liefert den virtuellen Bildschirm, Mesa rendert in Software):
##
##     xvfb-run -a -s "-screen 0 1280x720x24" \
##       ~/Applications/godot-4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
##       --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --script tools/shoot.gd ++ <szene> <ziel.png> [frames]
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


func _initialize() -> void:
	# Verzoegert, weil zu diesem Zeitpunkt weder Wurzelfenster noch Autoloads
	# fertig sind. _initialize() laeuft, bevor der Baum steht.
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Aufruf: --script tools/shoot.gd ++ <szene> <ziel.png> [frames]")
		quit(1)
		return

	var scene_path := args[0]
	var out_path := args[1] if args.size() > 1 else "res://shot.png"
	var frames := int(args[2]) if args.size() > 2 else DEFAULT_FRAMES

	var packed := ResourceLoader.load(scene_path) as PackedScene
	if packed == null:
		push_error("Szene nicht ladbar: %s" % scene_path)
		quit(1)
		return

	root.add_child(packed.instantiate())

	for i in frames:
		await process_frame

	# Der entscheidende Schritt. `get_image()` liest die Textur des Viewports
	# aus, und die ist erst nach dem Zeichnen gueltig - ohne dieses Warten
	# bekommt man ein leeres oder halb fertiges Bild zurueck.
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	if image == null:
		push_error("Kein Bild vom Viewport bekommen.")
		quit(1)
		return

	var error := image.save_png(out_path)
	if error != OK:
		push_error("Konnte %s nicht schreiben (Fehler %d)." % [out_path, error])
		quit(1)
		return

	print("SHOT %s -> %s (%dx%d)" % [scene_path, out_path, image.get_width(), image.get_height()])
	quit()
