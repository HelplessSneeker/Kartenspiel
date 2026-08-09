extends Control

## Energie pro Zug - fix, kein Ramp (Beschluss 07.08.2026).
const MAX_ENERGY := 4

## Karten, die zu Beginn jedes Spielerzugs gezogen werden.
##
## Bewusst groesser als MAX_ENERGY: bei fuenf Karten und vier Energie muss immer
## eine liegen bleiben. Das ist die kleinste Form einer Entscheidung, die ohne
## teure Karten auskommt - waeren es vier, spielte man einfach die Hand leer.
const HAND_SIZE := 5

## Wird im Inspector befuellt. Bleibt zur Laufzeit unangetastet -
## gezogen wird aus `deck`, das beim Start eine Kopie davon ist.
@export var starting_deck: Array[CardData] = []

## Was der Gegner tut, der Reihe nach und dann wieder von vorn.
@export var enemy_pattern: Array[EnemyAction] = []

## Beide Zahlen sind geraten, nicht gerechnet - ich kann das Spiel nicht spielen.
## Der Gegner ist hochgesetzt und der Spieler heruntergezogen worden, weil bei
## 60 zu 40 die Verteidigungskarten alles abgefangen haetten, was er austeilt:
## ein Gegner, der zuschlaegt und trotzdem egal ist, ist kein Fortschritt.
@export var player_max_health := 50
@export var enemy_max_health := 50

var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []
var energy: int = MAX_ENERGY

var player: Combatant
var enemy: Combatant
var brain: EnemyBrain

## Ab hier nimmt das Spiel keine Eingaben mehr an. Frueher stand dafuer
## `not enemy.is_alive()` in play_card() - das ging, solange nur der Gegner
## sterben konnte. Jetzt gibt es zwei Enden, und beide sollen dieselbe Sperre
## setzen, statt dass jede Abfrage sich ihre eigene Bedingung zusammensucht.
var _game_over := false


func _ready() -> void:
	player = Combatant.new(player_max_health)
	enemy = Combatant.new(enemy_max_health)
	player.died.connect(_on_player_died)
	enemy.died.connect(_on_enemy_died)
	%PlayerView.show_combatant(player)
	%EnemyView.show_combatant(enemy)

	brain = EnemyBrain.new(enemy_pattern)
	%Hand.card_clicked.connect(play_card)

	deck = starting_deck.duplicate()
	deck.shuffle()
	_start_player_turn()


# --- Rundenablauf -------------------------------------------------------------

## Ein Zugwechsel ist: Gegner handelt, dann faengt der Spieler neu an.
##
## Die Reihenfolge ist keine Geschmacksfrage. Wuerde der Spielerblock vor dem
## Gegnerangriff fallen, waere jede Verteidigungskarte wertlos - man wuerfe sie
## und der Schaden kaeme trotzdem voll durch. Block muss den Angriff ueberleben,
## gegen den er gespielt wurde, und erst danach verfallen.
func end_turn() -> void:
	if _game_over:
		return
	_enemy_turn()
	# Der Gegnerangriff kann den Spieler toeten. Dann darf kein neuer Zug mehr
	# aufgebaut werden - _on_player_died() hat inzwischen _game_over gesetzt.
	if _game_over:
		return
	_start_player_turn()


func _enemy_turn() -> void:
	# Der Block des Gegners haelt genau einen Spielerzug lang und faellt hier -
	# also erst, nachdem der Spieler die Gelegenheit hatte, dagegen anzurennen.
	# Spiegelbildlich zum Spielerblock, nur eine halbe Runde versetzt.
	enemy.clear_block()

	var action := brain.intent
	if action == null:
		return

	match action.kind:
		EnemyAction.Kind.BLOCK:
			enemy.add_block(action.amount)
		_:
			player.take_damage(action.amount)
			Sfx.play("card_play")


func _start_player_turn() -> void:
	player.clear_block()
	energy = MAX_ENERGY

	# Hand ablegen und neu ziehen, statt eine Karte nachzuziehen. Damit ist eine
	# nicht gespielte Karte am Zugende verloren - und "hebe ich die
	# Verteidigung fuer den Wuchtschlag auf?" hoert auf, eine Option zu sein.
	# Der Zug ist die Einheit, in der entschieden wird.
	_discard_hand()
	%Hand.discard_all()

	var drew := false
	for i in HAND_SIZE:
		drew = _draw_one() or drew
	if drew:
		Sfx.play("card_draw")
	%Hand.deal(hand, energy)

	# Erst jetzt steht fest, was der Gegner als naechstes tut - der Spieler
	# sieht seine neue Hand und die Drohung zusammen.
	brain.plan()
	refresh()


# --- Aktionen (Zustand aendern, danach anzeigen) ------------------------------

## Bekommt die angeklickte View, nicht nur ihre Daten - weil am Ende genau
## diese Karte zur Ablage fliegen soll und nicht irgendeine mit denselben Werten.
func play_card(view: CardView) -> void:
	if _game_over:
		return
	var card_data := view.data
	if card_data.cost > energy:
		Sfx.play("error")
		return

	Sfx.play("card_play")
	energy -= card_data.cost

	# Wer das Ziel ist, entscheidet noch die Karten-Art, nicht die Karte selbst.
	# Sobald es mehrere Gegner gibt, wandert das in eine echte Zielauswahl.
	if card_data.damage > 0:
		enemy.take_damage(card_data.damage)
	if card_data.block > 0:
		player.add_block(card_data.block)

	# erase() trifft den ersten Eintrag mit diesen Daten. Bei fuenf identischen
	# schlag.tres ist das egal - welche der fuenf gemeint war, entscheidet allein
	# die Anzeige, und die bekommt die View direkt.
	hand.erase(card_data)
	discard.append(card_data)
	%Hand.play_out(view)
	refresh()


# --- Zustand (kein Anfassen der Anzeige) -------------------------------------

## Zieht eine Karte in die Hand. Ohne refresh() - das machen die Aktionen,
## sonst wird beim Nachziehen fuenfmal unnoetig die Hand neu gebaut.
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


func _discard_hand() -> void:
	discard.append_array(hand)
	hand.clear()


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

## Nur noch das, was sich aus dem Zustand *ableitet*. Welche Karten auf dem
## Tisch liegen, ergibt sich nicht mehr hier: das sagen deal(), play_out() und
## discard_all() der Hand direkt, weil eine Bewegung wissen muss, was sich
## geaendert hat - und nicht nur, wie das Ergebnis aussieht.
func refresh() -> void:
	refresh_hud()
	refresh_intent()
	%Hand.set_energy(energy)


func refresh_hud() -> void:
	%EnergyLabel.text = "Energie: %d/%d" % [energy, MAX_ENERGY]
	%DeckPile.count = deck.size()
	%DiscardPile.count = discard.size()


## Zeigt die angekuendigte Gegneraktion.
##
## Das Label bleibt sichtbar und wird nur leer, statt versteckt zu werden: eine
## verschwindende Zeile in einem VBoxContainer laesst die Lebensanzeige
## darunter springen.
func refresh_intent() -> void:
	var action := brain.intent
	if action == null or _game_over:
		%IntentLabel.text = ""
		return
	var icon := "block" if action.kind == EnemyAction.Kind.BLOCK else "dmg"
	%IntentLabel.text = "[center]%s %d[/center]" % [Icons.bb(icon), action.amount]


# --- Signale ------------------------------------------------------------------

func _on_end_turn_button_pressed() -> void:
	Sfx.play("click")
	end_turn()


## Der Kampf blockiert nach dem Ende alle Eingaben. Solange das nirgends steht,
## sieht das Spiel dabei aus wie eingefroren - deshalb zeigt sich das Ergebnis,
## statt nur in der Konsole zu landen. Das Overlay liegt ueber allem und faengt
## Klicks ab; die Sperre in play_card() bleibt trotzdem, denn die Regel gehoert
## in die Logik und nicht in die Anzeige.
func _on_enemy_died() -> void:
	_end_game("Gegner besiegt")


func _on_player_died() -> void:
	_end_game("Du bist gefallen")


func _end_game(title: String) -> void:
	_game_over = true
	%EndTitle.text = title
	%EndOverlay.show()


func _on_retry_button_pressed() -> void:
	Sfx.play("click")
	get_tree().reload_current_scene()
