class_name Hand
extends Control

## Die Karten auf der Hand - und ihr Weg vom Ziehstapel hierher und zur Ablage.
##
## WICHTIGE ÄNDERUNG gegenueber vorher: die Hand baut sich nicht mehr bei jeder
## Zustandsaenderung komplett neu. `set_cards()` war bequem - "hier ist der
## Zustand, mach was draus" -, konnte aber prinzipiell nichts animieren: wer
## jedes Mal alles wegwirft und neu baut, weiss nie, *was* sich geaendert hat.
## Eine Karte, die zur Ablage fliegen soll, muss aber dieselbe Karte sein, die
## eben noch in der Hand lag.
##
## Deshalb bekommt die Hand jetzt Verben statt eines Zustands: austeilen,
## ablegen, alles abwerfen. game.gd bleibt die einzige Quelle der Wahrheit -
## es sagt der Hand, was passiert ist, statt nur, wie es danach aussieht.

## Reicht den Klick nach oben durch. Die Hand kennt keine Spielregeln -
## sie zeigt Karten an und meldet, wenn eine angeklickt wurde.
##
## Gemeldet wird die View, nicht mehr nur ihre Daten: das Deck enthaelt fuenfmal
## dieselbe `schlag.tres`, alle fuenf sind dieselbe Resource. Aus den Daten
## allein liesse sich nicht sagen, *welche* der drei Karten auf dem Tisch
## gemeint ist - und genau die soll gleich zur Ablage fliegen.
signal card_clicked(view: CardView)

const CARD_SCENE := preload("res://cards/card.tscn")

## Abstand zwischen zwei Karten, solange genug Platz ist.
@export var spacing := 12.0

## Abstand der Kartenunterkante zum unteren Bildschirmrand, wenn die Hand ruht.
@export var idle_offset := 0.0

## Dasselbe, solange die Maus in der Hand ist. Beide Zustaende haben bewusst
## ihre eigene Zahl - vorher hingen sie aneinander und liessen sich nicht
## unabhaengig einstellen.
@export var active_offset := 25.0

## Groesse der Karten im Ruhezustand.
@export var idle_scale := 0.8

## Groesse der Karte unter dem Cursor.
@export var hover_scale := 1.25

## Zusaetzlicher Hub der Karte unter dem Cursor. Default 0 - siehe Kommentar
## in _apply_layout(), das Ding kann Hover-Flackern ausloesen.
@export var hover_lift := 0.0

## Dauer der Uebergaenge innerhalb der Hand (zusammenruecken, hovern).
@export var tween_time := 0.12

## Woher Karten kommen und wohin sie gehen. Zeigt auf die beiden Pile-Knoten.
##
## Als NodePath und nicht als zwei Vector2 im Inspector: zieht man den Stapel
## im Editor um, wandert der Flugweg mit. Zwei von Hand gepflegte Zahlen waeren
## am ersten Layout-Umbau falsch, ohne dass es jemand merkt.
@export var deck_pile_path: NodePath
@export var discard_pile_path: NodePath

## Dauer eines Fluges zwischen Stapel und Hand. Deutlich laenger als
## tween_time - eine Bewegung, die man verfolgen koennen soll, darf nicht so
## schnell sein wie eine, die nur nicht ruckeln soll.
@export var travel_time := 0.3

## Versatz zwischen zwei Karten beim Austeilen.
@export var deal_delay := 0.08

## Groesse einer Karte, solange sie auf einem Stapel liegt.
@export var pile_scale := 0.55

var _views: Array[CardView] = []
var _hovered: CardView = null

## True, sobald die Maus irgendwo im Hand-Rechteck ist.
var _active := false

## Sperre gegen den eigenen Wiedereintritt, siehe _apply_layout().
var _laying_out := false


func _ready() -> void:
	mouse_entered.connect(_on_hand_mouse_entered)
	mouse_exited.connect(_on_hand_mouse_exited)
	resized.connect(_apply_layout.bind(false))


# --- Verben -------------------------------------------------------------------

## Teilt eine frische Hand aus. Die Karten starten auf dem Ziehstapel und
## fliegen nacheinander an ihren Platz.
##
## `energy` entscheidet nur, welche Karten als spielbar aussehen - die echte
## Regel liegt weiterhin in game.gd.
func deal(cards: Array[CardData], energy: int) -> void:
	# Erwartet eine leere Hand. Ist doch noch etwas da, gehoert es weg -
	# lieber hier abgeraeumt als spaeter als Geisterkarte gesucht.
	if not _views.is_empty():
		discard_all()

	for data in cards:
		var view: CardView = CARD_SCENE.instantiate()
		add_child(view)
		view.setup(data)
		view.playable = data.cost <= energy
		# Ohne Container muss die Karte ihre Groesse selbst annehmen.
		view.size = view.get_combined_minimum_size()
		# Skaliert wird um die Unterkante-Mitte: die Karte waechst nach oben
		# und zur Seite, ihr unterer Rand bleibt stehen.
		view.pivot_offset = Vector2(view.size.x * 0.5, view.size.y)
		view.mouse_entered.connect(_on_card_mouse_entered.bind(view))
		view.mouse_exited.connect(_on_card_mouse_exited.bind(view))
		view.clicked.connect(_on_card_clicked)
		_views.append(view)

	if _views.is_empty():
		return

	# Erst die Hand auf ihre Hoehe ziehen, dann die Startpunkte ausrechnen.
	# _pile_position() rechnet den Stapel aus globalen in Hand-Koordinaten um -
	# und die Hand verschiebt sich beim ersten Austeilen um ihre eigene Hoehe
	# nach oben. Andersherum starteten die Karten beim allerersten Zug rund 240
	# Pixel daneben, ab dem zweiten aber richtig: der unangenehme Fehler, der
	# nur einmal auftritt und deshalb wie ein Zufall aussieht.
	_fit_self(_views[0].size.y)

	# Startpunkt: der Ziehstapel. Von dort holt _apply_layout() sie ab.
	for view in _views:
		view.snap_to(_pile_position(deck_pile_path, 0.0, view.size), Vector2.ONE * pile_scale)

	_apply_layout(true, true)


## Eine gespielte Karte geht zur Ablage.
func play_out(view: CardView) -> void:
	_send_to_discard(view)
	_apply_layout()


## Zugende: die ganze Hand wandert auf die Ablage.
func discard_all() -> void:
	# Ueber eine Kopie, weil _send_to_discard() aus _views entfernt - eine Liste
	# waehrend der eigenen Schleife zu kuerzen ueberspringt jedes zweite Element.
	for view in _views.duplicate():
		_send_to_discard(view)
	_apply_layout()


## Faerbt um, welche Karten bezahlbar sind. Baut nichts neu.
func set_energy(energy: int) -> void:
	for view in _views:
		view.playable = view.data.cost <= energy


# --- Innenleben ---------------------------------------------------------------

## Entlaesst eine Karte aus der Hand und schickt sie zur Ablage.
##
## Sie fliegt zwar noch, gehoert aber ab sofort nicht mehr zur Hand: sie ist aus
## `_views` raus, also rechnet das Layout nicht mehr mit ihr, und sie nimmt keine
## Maus mehr an - sonst koennte man eine bereits gespielte Karte nochmal
## anklicken, waehrend sie davonfliegt.
func _send_to_discard(view: CardView) -> void:
	_views.erase(view)
	if _hovered == view:
		_hovered = null
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ueber allen anderen, damit der Weg zur Ablage nicht hinter der Hand
	# verschwindet.
	view.z_index = 200
	view.fly_out(
		_pile_position(discard_pile_path, size.x, view.size),
		Vector2.ONE * pile_scale,
		travel_time,
	)


## Wo eine Karte liegt, wenn sie auf einem Stapel liegt - in Hand-Koordinaten.
##
## Die Stapel stehen ausserhalb der Hand im Szenenbaum, deshalb der Umweg ueber
## die globale Transformation. `fallback_x` greift, solange kein Stapel gesetzt
## ist: dann fliegen die Karten an den unteren Rand statt ins Nichts.
func _pile_position(path: NodePath, fallback_x: float, card_size: Vector2) -> Vector2:
	var anchor := Vector2(fallback_x, size.y)
	var pile := get_node_or_null(path) as Control
	if pile != null:
		anchor = get_global_transform().affine_inverse() * pile.get_global_rect().get_center()
	# position ist die linke obere Ecke, gemeint ist aber der Punkt, um den
	# skaliert wird - Unterkante-Mitte, siehe pivot_offset.
	return anchor - Vector2(card_size.x * 0.5, card_size.y)


func _apply_layout(animate: bool = true, staggered: bool = false) -> void:
	var count := _views.size()
	if count == 0:
		return

	# _fit_self() aendert die eigene Hoehe und loest damit `resized` aus, das
	# wieder hier landet - mit animate = false. Ohne diese Sperre wuerde der
	# geschachtelte Aufruf die Karten sofort an ihr Ziel schnappen, und die
	# Animation, die der aeussere Aufruf gerade starten wollte, waere unsichtbar.
	if _laying_out:
		return
	_laying_out = true

	var card_size: Vector2 = _views[0].size
	_fit_self(card_size.y)

	# Alle Karten ausser der gehoverten haben diese Groesse. Der Abstand muss
	# daran haengen: rechnet man mit der unskalierten Breite, stehen
	# geschrumpfte Karten mit Luecken fuer ihre volle Groesse da.
	var base_scale := 1.0 if _active else idle_scale
	var visible_width := card_size.x * base_scale

	# Abstand von Kartenmitte zu Kartenmitte. Wird es zu eng, ruecken die
	# Karten zusammen und ueberlappen sich.
	var step := visible_width + spacing
	var span := step * (count - 1)
	if span + visible_width > size.x and count > 1:
		step = (size.x - visible_width) / float(count - 1)
		span = step * (count - 1)
	var first_center := (size.x - span) * 0.5

	var base_offset := active_offset if _active else idle_offset
	var duration := travel_time if staggered else tween_time

	for i in count:
		var view := _views[i]
		var is_hovered := _active and view == _hovered

		var target_scale := base_scale
		var offset := base_offset
		if is_hovered:
			target_scale = hover_scale
			offset += hover_lift

		# z_index steuert nur die Zeichenreihenfolge, nicht das Layout -
		# im Gegensatz zu move_to_front(), das die Kindreihenfolge aendert.
		#
		# Achtung: das wirkt nicht nur zwischen den Karten, sondern im ganzen
		# Canvas. Eine Karte mit z_index 2 zeichnet auch ueber Geschwister der
		# Hand, die auf 0 stehen - ein Overlay wuerde dann nur die erste Karte
		# verdecken. Was verlaesslich obenauf liegen soll, gehoert deshalb in
		# einen CanvasLayer, siehe OverlayLayer in game.tscn.
		view.z_index = 100 if is_hovered else i
		view.dimmed = not _active

		# pivot_offset sitzt auf Unterkante-Mitte, und genau dieser Punkt bleibt
		# beim Skalieren stehen. Deshalb wird er positioniert, nicht die Ecke.
		var target_pos := Vector2(
			first_center + step * i - card_size.x * 0.5,
			size.y - card_size.y - offset,
		)
		var delay := deal_delay * i if staggered else 0.0
		_move_to(view, target_pos, Vector2.ONE * target_scale, animate, duration, delay)

	_laying_out = false


## Die Hand zieht sich selbst auf die noetige Hoehe, statt sie aus einer von
## Hand gesetzten Inspector-Zahl zu beziehen - bei Hoehe 0 lagen die Karten
## unterhalb des Bildschirms. Der Zuschlag fuer hover_scale sorgt dafuer, dass
## auch die vergroesserte Karte noch im Rechteck liegt und die Maus-Erkennung
## nicht abreisst.
## Setzt Anchor-Preset "Bottom Wide" voraus (anchor_top == anchor_bottom == 1).
func _fit_self(card_height: float) -> void:
	var wanted := card_height * maxf(1.0, hover_scale) + maxf(idle_offset, active_offset)
	if is_equal_approx(size.y, wanted):
		return
	offset_top = -wanted
	offset_bottom = 0.0


func _move_to(
	view: CardView,
	pos: Vector2,
	card_scale: Vector2,
	animate: bool,
	duration: float,
	delay: float,
) -> void:
	if animate:
		view.animate_to(pos, card_scale, duration, delay)
	else:
		view.snap_to(pos, card_scale)


# --- Signale ------------------------------------------------------------------

func _on_hand_mouse_entered() -> void:
	_active = true
	_apply_layout()


func _on_hand_mouse_exited() -> void:
	_active = false
	_hovered = null
	_apply_layout()


func _on_card_mouse_entered(view: CardView) -> void:
	_active = true
	_hovered = view
	_apply_layout()


func _on_card_mouse_exited(view: CardView) -> void:
	if _hovered != view:
		return
	_hovered = null
	# Eine vergroesserte Karte kann ueber den Rand der Hand hinausragen. Verlaesst
	# der Cursor sie dort, feuert `mouse_exited` der Hand nie - deshalb hier
	# selbst nachsehen, statt auf das Signal zu warten.
	_active = get_global_rect().has_point(get_global_mouse_position())
	_apply_layout()


func _on_card_clicked(view: CardView) -> void:
	card_clicked.emit(view)
