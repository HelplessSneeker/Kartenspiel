class_name CardView
extends PanelContainer

## Wird gefeuert, wenn auf diese Karte geklickt wird.
## Die Karte selbst weiss nicht, was "spielen" bedeutet - das entscheidet game.gd.
signal clicked(card: CardView)

const UNPLAYABLE_TINT := Color(0.55, 0.55, 0.55)

var data: CardData


func setup(new_data: CardData) -> void:
	data = new_data
	%NameLabel.text = data.card_name
	%CostLabel.text = "Kosten: %d" % data.cost
	%TextLabel.text = data.description.format({
		"damage": data.damage,
		"block": data.block,
	})


## Rein optisch - die Regel, ob gespielt werden darf, liegt in game.gd.
func set_playable(playable: bool) -> void:
	modulate = Color.WHITE if playable else UNPLAYABLE_TINT


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
