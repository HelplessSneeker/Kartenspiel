class_name CardView
extends PanelContainer

## Wird gefeuert, wenn auf diese Karte geklickt wird.
## Die Karte selbst weiss nicht, was "spielen" bedeutet - das entscheidet game.gd.
signal clicked(card: CardView)

## Zu teuer - dauerhafter Zustand, haengt an der Energie.
const UNPLAYABLE_TINT := Color(0.55, 0.55, 0.55)

## Hand ruht - voruebergehender Zustand, haengt an der Maus.
const IDLE_TINT := Color(0.65, 0.65, 0.7)

## Kartenruecken. Der Default-Theme liefert fuer PanelContainer eine
## halbtransparente Flaeche - fuer eine Karte, die andere Karten ueberlappt,
## unbrauchbar. Deshalb ein eigener StyleBox statt des Theme-Panels.
const BG_COLOR := Color("232839")
const BORDER_COLOR := Color("454d69")
const CORNER_RADIUS := 8
const BORDER_WIDTH := 2

var data: CardData

## Beide Faerbungen sind unabhaengig voneinander und werden multipliziert:
## eine zu teure Karte in einer ruhenden Hand ist doppelt abgedunkelt.
var playable := true:
	set(value):
		playable = value
		_update_tint()

var dimmed := false:
	set(value):
		dimmed = value
		_update_tint()

var _tween: Tween


func _ready() -> void:
	add_theme_stylebox_override("panel", _build_style())


## Bewusst im Code statt im Editor: das Aussehen soll spaeter von den
## Kartendaten abhaengen koennen (Kategorie, Seltenheit), und dafuer braucht
## es sowieso einen Ort, an dem der StyleBox gebaut wird.
func _build_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(BORDER_WIDTH)
	style.set_corner_radius_all(CORNER_RADIUS)
	return style


func setup(new_data: CardData) -> void:
	data = new_data
	%NameLabel.text = data.card_name
	%CostLabel.text = "Kosten: %d" % data.cost
	%TextLabel.text = data.description.format({
		"damage": data.damage,
		"block": data.block,
	})


func snap_to(target_position: Vector2, target_scale: Vector2) -> void:
	_kill_tween()
	position = target_position
	scale = target_scale


func animate_to(target_position: Vector2, target_scale: Vector2, duration: float) -> void:
	# Ein laufender Tween muss weg, sonst zerren zwei um dieselbe Property
	# und die Karte zittert zwischen zwei Zielen.
	_kill_tween()
	_tween = create_tween().set_parallel()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target_position, duration)
	_tween.tween_property(self, "scale", target_scale, duration)


func _update_tint() -> void:
	var tint := Color.WHITE
	if not playable:
		tint *= UNPLAYABLE_TINT
	if dimmed:
		tint *= IDLE_TINT
	modulate = tint


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
