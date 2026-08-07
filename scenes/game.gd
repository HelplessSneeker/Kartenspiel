extends Control

const CARD_SCENE := preload("res://cards/card.tscn")

## Energie pro Zug - fix, kein Ramp (Beschluss 07.08.2026).
const MAX_ENERGY := 4

## Wird im Inspector befuellt. Bleibt unangetastet - gezogen wird aus `deck`.
@export var starting_deck: Array[CardData] = []

var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []
var energy: int = MAX_ENERGY


func _ready() -> void:
	deck = starting_deck.duplicate()
	deck.shuffle()
	refresh()


func draw_card() -> void:
	if deck.is_empty():
		return
	hand.append(deck.pop_back())
	refresh()


# --- DEIN PART ---------------------------------------------------------------

## Energie pruefen, abziehen, Effekt anwenden, Karte von `hand` nach `discard`,
## am Ende refresh(). Effekt vorerst nur print().
func play_card(card_data: CardData) -> void:
	pass


## Energie auffuellen, eine Karte ziehen.
func end_turn() -> void:
	pass


## Die drei Labels aus `deck`, `discard` und `energy` fuellen.
func refresh_hud() -> void:
	pass


# --- Zustand -> Anzeige -------------------------------------------------------

func refresh() -> void:
	refresh_hand()
	refresh_hud()


## Baut die Hand komplett aus `hand` neu auf. Einziger Ort, an dem
## HandContainer-Kinder entstehen oder verschwinden.
func refresh_hand() -> void:
	for child in %HandContainer.get_children():
		%HandContainer.remove_child(child)
		child.queue_free()

	for card_data in hand:
		var card: CardView = CARD_SCENE.instantiate()
		%HandContainer.add_child(card)
		card.setup(card_data)
		card.clicked.connect(_on_card_clicked)


# --- Signale ------------------------------------------------------------------

func _on_card_clicked(card: CardView) -> void:
	play_card(card.data)


func _on_draw_button_pressed() -> void:
	draw_card()


func _on_end_turn_button_pressed() -> void:
	end_turn()
