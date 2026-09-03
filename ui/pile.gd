class_name Pile
extends PanelContainer

## Ein Kartenstapel als Ort auf dem Tisch: Ziehstapel und Ablage.
##
## Vorher standen beide Zahlen als Text in der Kopfleiste. Das sagt, *wieviel*
## irgendwo liegt, aber nicht *wo* - und eine gespielte Karte verschwand
## ersatzlos, statt irgendwohin zu gehen. Der Stapel ist deshalb nicht nur
## huebscher, er ist der Zielpunkt, den die Kartenanimation braucht: hand.gd
## rechnet die Flugbahn aus der Position dieses Knotens aus.
##
## Kennt weder Deck noch Ablage - er zeigt eine Zahl und eine Beschriftung.
## Wer ihn womit fuellt, entscheidet game.gd.
##
## ACHTUNG, Reihenfolge im Baum: seit der Stapel anklickbar ist, muss er in
## game.tscn *nach* der Hand stehen. Die Hand spannt ueber das untere
## Bildschirmdrittel und ist ein Control mit mouse_filter = STOP - sie liegt also
## ueber beiden Stapeln und schluckt jeden Klick darauf. Nicht ueber
## mouse_filter geloest, weil die Hand ihr eigenes mouse_entered fuer die
## Hover-Logik braucht; dieselbe Falle wie beim unklickbaren Knopf am 30.08.2026.

## Auf den Stapel geklickt. Was dann passiert - naemlich die Liste zeigen -
## entscheidet game.gd, wie beim Klick auf eine Karte.
signal clicked

## Aufhellung, solange die Maus darauf steht.
##
## Werte ueber 1 in modulate hellen auf, statt zu faerben. Reicht als Hinweis,
## dass hier etwas passiert - zusammen mit dem Zeigefinger-Cursor aus der .tscn.
const HOVER_TINT := Color(1.25, 1.25, 1.25)

## Die Kartenrueckseite, die im Stapel liegt. Leer heisst: nur der Rahmen.
##
## Nur der Ziehstapel hat eine. Auf der Ablage waere sie falsch herum gedacht -
## dort liegen gespielte Karten mit dem Gesicht nach oben, und eine Rueckseite
## haette dort dieselbe Aussage wie "hier liegt irgendwas".
##
## Als @export und nicht fest in der Szene, weil dieselbe Szene beide Stapel
## bedient - dieselbe Ueberlegung wie bei `title`.
##
## Die 70% Deckkraft stehen an der TextureRect in der .tscn und nicht hier: die
## Zahl liegt mitten auf dem Rautenwappen, und bei voller Deckkraft streiten
## sich beide. Nachgesehen an einer Simulation in Anzeigegroesse, nicht geraten.
@export var back: Texture2D:
	set(value):
		back = value
		if is_node_ready():
			_apply_back()

## Beschriftung unter der Zahl. Steht im Inspector, damit dieselbe Szene fuer
## beide Stapel reicht - wie bei HealthView.
@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			%TitleLabel.text = title

var count: int = 0:
	set(value):
		count = value
		if is_node_ready():
			%CountLabel.text = str(count)


func _ready() -> void:
	%TitleLabel.text = title
	%CountLabel.text = str(count)
	_apply_back()
	mouse_entered.connect(func() -> void: modulate = HOVER_TINT)
	mouse_exited.connect(func() -> void: modulate = Color.WHITE)


## Ohne Bild bleibt die TextureRect unsichtbar statt leer sichtbar - sonst
## liegt im Ablagestapel ein durchsichtiges Rechteck, das nichts tut.
func _apply_back() -> void:
	%BackRect.texture = back
	%BackRect.visible = back != null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
