extends Control

## Energie pro Zug - fix, kein Ramp (Beschluss 07.08.2026).
const MAX_ENERGY := 4

## Karten, die zu Rundenbeginn auf der Hand liegen.
const STARTING_HAND := 5

## Wird im Inspector befuellt. Bleibt zur Laufzeit unangetastet -
## gezogen wird aus `deck`, das beim Start eine Kopie davon ist.
@export var starting_deck: Array[CardData] = []

@export var player_max_health := 60
@export var enemy_max_health := 40

var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []
var energy: int = MAX_ENERGY

var player: Combatant
var enemy: Combatant


func _ready() -> void:
	player = Combatant.new(player_max_health)
	enemy = Combatant.new(enemy_max_health)
	enemy.died.connect(_on_enemy_died)
	%PlayerView.show_combatant(player)
	%EnemyView.show_combatant(enemy)

	%Hand.card_clicked.connect(play_card)
	deck = starting_deck.duplicate()
	deck.shuffle()
	for i in STARTING_HAND:
		_draw_one()
	refresh()


# --- Aktionen (Zustand aendern, danach anzeigen) ------------------------------

func draw_card() -> void:
	if _draw_one():
		Sfx.play("card_draw")
	refresh()


func play_card(card_data: CardData) -> void:
	if card_data.cost > energy:
		Sfx.play("error")
		print("Zu teuer: %s kostet %d, du hast %d." % [
			card_data.card_name, card_data.cost, energy,
		])
		return
	if not enemy.is_alive():
		return

	Sfx.play("card_play")
	energy -= card_data.cost

	# Wer das Ziel ist, entscheidet noch die Karten-Art, nicht die Karte selbst.
	# Sobald es mehrere Gegner gibt, wandert das in eine echte Zielauswahl.
	if card_data.damage > 0:
		enemy.take_damage(card_data.damage)
	if card_data.block > 0:
		player.add_block(card_data.block)

	hand.erase(card_data)
	discard.append(card_data)
	refresh()


func end_turn() -> void:
	# Block haelt nur eine Runde - sonst staut er sich unbegrenzt auf.
	player.clear_block()
	energy = MAX_ENERGY
	if _draw_one():
		Sfx.play("card_draw")
	refresh()


# --- Zustand (kein Anfassen der Anzeige) -------------------------------------

## Zieht eine Karte in die Hand. Ohne refresh() - das machen die Aktionen,
## sonst wird beim Startblatt fuenfmal unnoetig die Hand neu gebaut.
##
## Gibt zurueck, ob tatsaechlich gezogen wurde. Sind Stapel und Ablage beide
## leer, passiert nichts - und dann soll auch kein Ziehgeraeusch kommen.
func _draw_one() -> bool:
	if deck.is_empty():
		_reshuffle_discard()
	if deck.is_empty():
		return false
	hand.append(deck.pop_back())
	return true


## Ziehstapel leer -> Ablage zurueckmischen.
##
## Bewusst ohne Sound: das Mischgeraeusch ist deutlich laenger als die anderen
## und draengt sich mitten im Zug in den Vordergrund. Zum Zurueckholen genuegt
## ein Sfx.play("shuffle") - Datei und Eintrag liegen weiterhin bereit.
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


func refresh_hand() -> void:
	%Hand.set_cards(hand, energy)


func refresh_hud() -> void:
	%DeckLabel.text = "Deck: %d" % deck.size()
	%EnergyLabel.text = "Energie: %d/%d" % [energy, MAX_ENERGY]
	%DiscardLabel.text = "Ablage: %d" % discard.size()


# --- Signale ------------------------------------------------------------------

func _on_draw_button_pressed() -> void:
	draw_card()


func _on_end_turn_button_pressed() -> void:
	end_turn()


## Der Kampf blockiert nach dem Sieg alle Karten. Solange das nirgends steht,
## sieht das Spiel dabei aus wie eingefroren - deshalb zeigt der Sieg sich, statt
## nur in der Konsole zu landen. Das Overlay liegt ueber allem und faengt Klicks
## ab; die Sperre in play_card() bleibt trotzdem, denn die Regel gehoert in die
## Logik und nicht in die Anzeige.
func _on_enemy_died() -> void:
	%VictoryOverlay.show()


func _on_retry_button_pressed() -> void:
	Sfx.play("click")
	get_tree().reload_current_scene()
