extends Node

## Weiche Blende zwischen den Bildschirmen, als Autoload unter dem Namen `Fade`.
##
## Jeder Wechsel war bis hierher ein harter Schnitt: Menue -> Kampf, Kampf ->
## Kampf, Kampf -> Menue. Bei einem Spiel, das inzwischen ueberall Bewegung hat
## - Karten fliegen, Zahlen steigen auf, Balken laufen nach -, ist der
## Bildschirmwechsel die einzige Stelle, an der etwas *springt*. Und er ist die
## auffaelligste, weil das ganze Bild betroffen ist.
##
## Warum ein Autoload und keine Blende je Szene? Weil eine Blende genau den
## Moment ueberdauern muss, in dem die alte Szene stirbt und die neue noch nicht
## steht. Alles, was in einer der beiden Szenen haengt, ist in diesem Moment
## entweder schon weg oder noch nicht da.
##
## Die Knoten werden im Code gebaut statt aus einer .tscn geladen - dieselbe
## Bauart wie die Audio-Autoloads: ein CanvasLayer und ein ColorRect sind
## weniger Datei als Zeile.

## Ausblenden geht schneller als einblenden. Wer geklickt hat, will weg -
## Warten auf das Verschwinden fuehlt sich traeger an als das Ankommen, bei dem
## man ohnehin gerade erst hinsieht.
const OUT_TIME := 0.20
const IN_TIME := 0.28

## Nicht Schwarz, sondern der unterste Ton des Hintergrundverlaufs. Das Spiel
## hat ein eigenes Dunkel; ein reines Schwarz dazwischen waere ein fremder Ton
## in einer Palette, die sonst durchgehalten wird.
const COLOR := Color(0.0431373, 0.0352941, 0.0235294)

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	# Ohne das steht die Blende still, sobald das Pausenmenue den Baum anhaelt -
	# und der Weg "Pause -> Hauptmenue" ist genau einer der Wechsel, um die es
	# hier geht. Dieselbe Zeile wie im Sfx-Autoload, aus demselben Grund.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var layer := CanvasLayer.new()
	# Ueber allem: der OverlayLayer im Kampf liegt auf 10, der PauseLayer auf 20.
	# Eine Blende, die das Pausenmenue stehen laesst, blendet nur das halbe Bild.
	layer.layer = 128
	add_child(layer)

	_rect = ColorRect.new()
	_rect.color = COLOR
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Ausserhalb einer Blende faengt das Rechteck nichts ab. Waehrend einer schon -
	# siehe _swap(): ein Klick, der auf halbem Weg in der neuen Szene landet,
	# trifft dort etwas, das der Spieler noch gar nicht gesehen hat.
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_rect)

	# Der allererste Bildschirm blendet auf, statt aufzuploppen. Deshalb faengt
	# das Rechteck deckend an und nicht durchsichtig.
	await _fade(0.0, IN_TIME)


func change_scene(path: String) -> void:
	await _swap(func() -> void: get_tree().change_scene_to_file(path))


func reload_scene() -> void:
	await _swap(func() -> void: get_tree().reload_current_scene())


## Ausblenden, tauschen, einblenden.
##
## `swap` als Callable, weil sich Szenenwechsel und Neuladen nur in dieser einen
## Zeile unterscheiden - alles davor und danach ist identisch.
##
## Die Sperre ist kein Luxus: zweimal schnell auf "Weiter" geklickt wuerde sonst
## zwei Blenden gleichzeitig starten, die beide an derselben Farbe ziehen, und
## der zweite Szenenwechsel kaeme in einem halb aufgeblendeten Bild an.
func _swap(swap: Callable) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	await _fade(1.0, OUT_TIME)
	swap.call()
	# Ein Frame Pause, bevor wieder aufgeblendet wird: change_scene_to_file()
	# wechselt nicht sofort, sondern am Ende des laufenden Frames. Ohne das
	# Warten blendet die Blende die *alte* Szene wieder auf und springt dann.
	await get_tree().process_frame
	await _fade(0.0, IN_TIME)

	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade(to_alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", to_alpha, duration)
	await tween.finished
