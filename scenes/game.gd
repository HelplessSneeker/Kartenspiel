extends Control

const CARD_SCENE := preload("res://cards/card.tscn")

## Energie pro Zug - fix, kein Ramp (Beschluss 07.08.2026).
const MAX_ENERGY := 4

## Karten, die zu Rundenbeginn auf der Hand liegen.
const STARTING_HAND := 5

## Wird im Inspector befuellt. Bleibt zur Laufzeit unangetastet -
## gezogen wird aus `deck`, das beim Start eine Kopie davon ist.
@export var starting_deck: Array[CardData] = []

var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []
var energy: int = MAX_ENERGY


func _ready() -> void:
	deck = starting_deck.duplicate()
	deck.shuffle()
	for i in STARTING_HAND:
		_draw_one()
	refresh()


# --- Aktionen (Zustand aendern, danach anzeigen) ------------------------------

func draw_card() -> void:
	_draw_one()
	refresh()


func play_card(card_data: CardData) -> void:
	if card_data.cost > energy:
		print("Zu teuer: %s kostet %d, du hast %d." % [
			card_data.card_name, card_data.cost, energy,
		])
		return

	energy -= card_data.cost

	if card_data.damage > 0:
		print("%s -> %d Schaden" % [card_data.card_name, card_data.damage])
	if card_data.block > 0:
		print("%s -> %d Block" % [card_data.card_name, card_data.block])

	hand.erase(card_data)
	discard.append(card_data)
	refresh()


func end_turn() -> void:
	energy = MAX_ENERGY
	_draw_one()
	refresh()


# --- Zustand (kein Anfassen der Anzeige) -------------------------------------

## Zieht eine Karte in die Hand. Ohne refresh() - das machen die Aktionen,
## sonst wird beim Startblatt fuenfmal unnoetig die Hand neu gebaut.
func _draw_one() -> void:
	if deck.is_empty():
		_reshuffle_discard()
	if deck.is_empty():
		return
	hand.append(deck.pop_back())


## Ziehstapel leer -> Ablage zurueckmischen.
func _reshuffle_discard() -> void:
	if discard.is_empty():
		return
	deck.append_array(discard)
	discard.clear()
	deck.shuffle()


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
		card.set_playable(card_data.cost <= energy)
		card.clicked.connect(_on_card_clicked)


func refresh_hud() -> void:
	%DeckLabel.text = "Deck: %d" % deck.size()
	%EnergyLabel.text = "Energie: %d/%d" % [energy, MAX_ENERGY]
	%DiscardLabel.text = "Ablage: %d" % discard.size()


# --- Signale ------------------------------------------------------------------

func _on_card_clicked(card: CardView) -> void:
	play_card(card.data)


func _on_draw_button_pressed() -> void:
	draw_card()


func _on_end_turn_button_pressed() -> void:
	end_turn()
