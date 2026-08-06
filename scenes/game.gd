extends Control

@export var deck: Array[CardData] = []
const CARD_SCENE = preload("res://cards/card.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	deck.shuffle()

func draw_card()-> void:
	if deck.is_empty():
		return
	var card_data = deck.pop_back()
	var card = CARD_SCENE.instantiate();
	%HandContainer.add_child(card)
	card.setup(card_data)

func _on_draw_button_pressed() -> void:
	draw_card()
	
