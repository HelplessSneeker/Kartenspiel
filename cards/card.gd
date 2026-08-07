class_name CardView
extends PanelContainer

## Wird gefeuert, wenn auf diese Karte geklickt wird.
## Die Karte selbst weiss nicht, was "spielen" bedeutet - das entscheidet game.gd.
signal clicked(card: CardView)

## Zu teuer - dauerhafter Zustand, haengt an der Energie.
const UNPLAYABLE_TINT := Color(0.55, 0.55, 0.55)

## Hand ruht - voruebergehender Zustand, haengt an der Maus.
const IDLE_TINT := Color(0.65, 0.65, 0.7)

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
