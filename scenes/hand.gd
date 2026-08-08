class_name Hand
extends Control

## Reicht den Klick nach oben durch. Die Hand kennt keine Spielregeln -
## sie zeigt Karten an und meldet, wenn eine angeklickt wurde.
signal card_clicked(data: CardData)

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

## Dauer der Uebergaenge in Sekunden.
@export var tween_time := 0.12

var _views: Array[CardView] = []
var _hovered: CardView = null

## True, sobald die Maus irgendwo im Hand-Rechteck ist.
var _active := false


func _ready() -> void:
	mouse_entered.connect(_on_hand_mouse_entered)
	mouse_exited.connect(_on_hand_mouse_exited)
	resized.connect(_apply_layout.bind(false))


## Baut die Hand komplett neu auf. `energy` entscheidet nur, welche Karten
## als spielbar aussehen - die echte Regel liegt weiterhin in game.gd.
func set_cards(cards: Array[CardData], energy: int) -> void:
	for view in _views:
		remove_child(view)
		view.queue_free()
	_views.clear()
	_hovered = null

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

	_apply_layout(false)


func _apply_layout(animate: bool = true) -> void:
	var count := _views.size()
	if count == 0:
		return

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
		_move_to(view, target_pos, Vector2.ONE * target_scale, animate)


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


func _move_to(view: CardView, pos: Vector2, card_scale: Vector2, animate: bool) -> void:
	if animate:
		view.animate_to(pos, card_scale, tween_time)
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
	card_clicked.emit(view.data)
