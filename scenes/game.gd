extends Control

## Energie pro Zug - fix, kein Ramp (Beschluss 07.08.2026).
const MAX_ENERGY := 4

## Karten, die zu Beginn jedes Spielerzugs gezogen werden.
##
## Bewusst groesser als MAX_ENERGY: bei fuenf Karten und vier Energie muss immer
## eine liegen bleiben. Das ist die kleinste Form einer Entscheidung, die ohne
## teure Karten auskommt - waeren es vier, spielte man einfach die Hand leer.
const HAND_SIZE := 5

## Wie der Aktionsname ueber der Drohung gesetzt wird.
##
## Als BBCode und nicht als Theme-Variation, weil beides in *einem* Label steht:
## Name und Zahlen sollen zusammen zentriert bleiben und zusammen verschwinden.
## Zwei Labels waeren sauberer getrennt, muessten sich dafuer aber beide um
## Sichtbarkeit und Ausrichtung kuemmern - fuer eine Zeile Kleingedrucktes ist
## das der teurere Weg.
const INTENT_NAME_FORMAT := "[font_size=14][color=#8f96ab]%s[/color][/font_size]"

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

## Was ueber dem Bildschirm steht, wenn der Spieler verliert.
##
## Steht hier, weil es zum Gegner gehoert und nicht zum Spieler: gegen das Kind
## verliert man nicht, indem man stirbt, sondern indem man nachgibt. Solange es
## nur einen Kampf gibt, ist ein @export der richtige Ort dafuer. Sobald die
## Kaempfe eine Reihe bilden, zieht das Feld mit dem Gegner in dessen eigene
## Resource um - zusammen mit Leben, Portraet und Muster.
@export var defeat_title := "Du bist gefallen"

var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []
var energy: int = MAX_ENERGY

## Wie viel Energie im *naechsten* Spielerzug fehlt. Wird beim Zugbeginn
## verrechnet und dabei geleert.
##
## Warum nicht sofort von `energy` abziehen, wenn das Kind sich ans Bein haengt?
## Weil der Gegner am Ende des Spielerzugs handelt - da ist die Energie ohnehin
## verbraucht, ein Abzug waere folgenlos. Die Wirkung muss ankommen, wenn der
## Spieler das naechste Mal etwas damit vorhat.
var _energy_penalty := 0

var player: Combatant
var enemy: Combatant
var brain: EnemyBrain

## Ab hier nimmt das Spiel keine Eingaben mehr an. Frueher stand dafuer
## `not enemy.is_alive()` in play_card() - das ging, solange nur der Gegner
## sterben konnte. Jetzt gibt es zwei Enden, und beide sollen dieselbe Sperre
## setzen, statt dass jede Abfrage sich ihre eigene Bedingung zusammensucht.
var _game_over := false


func _ready() -> void:
	Music.play("battle")
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

	# Die Aktion sagt selbst, wie sie klingt. Vorher stand hier is_attack() und
	# lieh sich den Kartenlegeton - das war ein Behelf aus der Zeit, in der der
	# Gegner nur schlagen oder blocken konnte.
	if not action.sound.is_empty():
		Sfx.play(action.sound)

	# Dieselbe Schleife wie beim Kartenspielen, nur mit vertauschten Rollen.
	# Genau das ist der Gewinn daran, dass beide Seiten CardEffect benutzen:
	# "Gegner blockt" und "Spieler blockt" sind nicht mehr zwei Code-Wege, die
	# man getrennt richtig halten muss.
	for effect in action.effects:
		_apply_effect(effect, enemy, player)
		if _game_over:
			break


func _start_player_turn() -> void:
	player.clear_block()
	# maxi(), damit ein zu gieriger Entzug nicht in negative Energie laeuft: bei
	# -1 waere selbst eine Nullkosten-Karte gesperrt, und die Hand saehe aus, als
	# waere sie kaputt statt teuer.
	energy = maxi(MAX_ENERGY - _energy_penalty, 0)
	_energy_penalty = 0

	# Hand ablegen und neu ziehen, statt eine Karte nachzuziehen. Damit ist eine
	# nicht gespielte Karte am Zugende verloren - und "hebe ich die
	# Verteidigung fuer den Wuchtschlag auf?" hoert auf, eine Option zu sein.
	# Der Zug ist die Einheit, in der entschieden wird.
	_discard_hand()
	%Hand.discard_all()

	if not _draw_cards(HAND_SIZE).is_empty():
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
	# Zwei Absagen, ein Geraeusch. Ein eigener Ton fuer "geht nie" waere ehrlicher,
	# aber es gibt ihn noch nicht - und die Karte sagt es ohnehin selbst: grauer
	# Rahmen, kein Preis, "Unspielbar" im Text.
	if not card_data.is_playable() or card_data.cost > energy:
		Sfx.play("error")
		return

	# Eigener Ton, wenn die Karte einen nennt - sonst der allgemeine Legeton.
	Sfx.play(card_data.sound if not card_data.sound.is_empty() else "card_play")
	energy -= card_data.cost

	# Die Karte verlaesst die Hand, *bevor* sie wirkt. Sonst zieht eine Karte mit
	# "ziehe 2" Karten in eine Hand, in der sie selbst noch liegt - und die
	# frisch gezogene wandert gleich mit auf die Ablage.
	#
	# erase() trifft den ersten Eintrag mit diesen Daten. Bei drei identischen
	# Angriffskarten ist das egal - welche der drei gemeint war, entscheidet allein
	# die Anzeige, und die bekommt die View direkt.
	hand.erase(card_data)
	discard.append(card_data)
	%Hand.play_out(view)

	for effect in card_data.effects:
		_apply_effect(effect, player, enemy)
		# Eine Karte kann beide Seiten toeten (Aderlass gegen einen Gegner mit
		# 5 Leben). Was danach in der Liste steht, darf dann nicht mehr wirken.
		if _game_over:
			break

	refresh()


## Fuehrt eine einzelne Wirkung aus.
##
## Warum hier und nicht in CardEffect selbst? Weil eine Wirkung Zugriff auf
## alles braucht, was der Kampf hat: beide Kaempfer, den Ziehstapel, die
## Energie, die Hand. Laege sie in der Resource, muesste man ihr das alles
## mitgeben - und CardEffect wuesste dann, wie ein Kampf aufgebaut ist. So
## bleibt es bei der Trennung, die ueberall in diesem Projekt gilt: die .tres
## sagt *was*, der Code sagt *wie*.
##
## Wer das Ziel ist, entscheidet weiterhin die Art der Wirkung, nicht die Karte.
## Sobald es mehrere Gegner gibt, kommt hier eine echte Zielauswahl dazu.
##
## `actor` und `target` sind neu und der Grund, warum der Gegner ueberhaupt
## Karteneffekte benutzen kann. Vorher stand hier `enemy.take_damage()` und
## `player.add_block()` fest verdrahtet - das war dieselbe Annahme wie an vielen
## Stellen im fruehen Code: es gibt nur eine Seite, die handelt. Jetzt sagt die
## Wirkung, *was* passiert, und der Aufrufer, *wem*.
##
## SCHADEN geht ans Gegenueber, BLOCK/HEILEN/SELBSTSCHADEN an den Handelnden
## selbst. Damit ist "Lecker Bierchen" beim Spieler und "Schmollen" beim Kind
## exakt dieselbe Wirkung, nur mit anderen Rollen.
func _apply_effect(effect: CardEffect, actor: Combatant, target: Combatant) -> void:
	if effect == null:
		return

	match effect.kind:
		CardEffect.Kind.SCHADEN:
			target.take_damage(effect.amount)
		CardEffect.Kind.BLOCK:
			actor.add_block(effect.amount)
		CardEffect.Kind.HEILEN:
			actor.heal(effect.amount)
		CardEffect.Kind.SELBSTSCHADEN:
			actor.take_damage(effect.amount)
		# Energie und Ziehstapel hat nur der Spieler. Ein Gegner, der "ziehe 2"
		# in seiner Liste haette, wuerde sonst stumm in die Hand des Spielers
		# greifen - der Fehler faellt dann irgendwann im Spiel auf statt beim
		# Bauen der .tres. Deshalb Warnung statt stiller Wirkung.
		CardEffect.Kind.ENERGIE:
			if _is_player(actor, effect.kind):
				energy += effect.amount
		CardEffect.Kind.ZIEHEN:
			if _is_player(actor, effect.kind):
				_draw_into_hand(effect.amount)
		# Entzug und Zuschieben treffen dagegen *immer* den Spieler, egal wer
		# wirkt: es gibt nur eine Energie und nur eine Ablage. Eine Karte mit
		# ENERGIE_ENTZUG waere also eine Karte, die sich selbst bestraft - die
		# Sucht-Steuer aus dem Design-Doc genau in der Form, die dort steht.
		CardEffect.Kind.ENERGIE_ENTZUG:
			_energy_penalty += effect.amount
		CardEffect.Kind.KARTE_ZUSCHIEBEN:
			_push_card(effect.card as CardData, effect.amount)


func _is_player(actor: Combatant, kind: CardEffect.Kind) -> bool:
	if actor == player:
		return true
	push_warning("Wirkung %s wirkt nur beim Spieler und wurde uebergangen." % kind)
	return false


## Legt `count` Kopien einer Karte auf die Ablage des Spielers.
##
## Auf die Ablage und nicht in die Hand: eine Karte, die sofort in der Hand
## landet, verdraengt nichts - die Hand ist zu dem Zeitpunkt ohnehin gleich
## fertig. Auf der Ablage wandert sie beim naechsten Mischen in den Ziehstapel
## und belegt von da an *irgendwann* einen Platz. Das ist die Wirkung, die
## gemeint ist: nicht ein schlechter Zug, sondern ein schlechteres Deck.
##
## Dieselbe Resource mehrfach in die Liste, keine Kopie pro Stueck: Karten sind
## hier durchgehend geteilte Daten (das Startdeck haelt Watschn ebenfalls
## fuenfmal als denselben Verweis), und CardData wird zur Laufzeit nicht
## veraendert. play_card() erase()t den ersten passenden Eintrag - welche der
## identischen Karten das trifft, ist genau deshalb egal.
func _push_card(card: CardData, count: int) -> void:
	if card == null or count <= 0:
		push_warning("KARTE_ZUSCHIEBEN ohne Karte oder ohne Anzahl.")
		return
	for i in count:
		discard.append(card)


## Zieht mitten im Zug nach - Zustand und Anzeige in einem Schritt.
##
## Beim Zugbeginn laeuft das getrennt (erst alles ziehen, dann einmal
## austeilen), weil dort fuenf Karten auf einmal kommen und die Hand vorher
## leer ist. Hier kommen ein oder zwei in eine bestehende Hand - der Unterschied
## ist die ganze Begruendung fuer das zweite Verb in hand.gd.
## Den Ziehton spielt hier ausnahmsweise die Hand selbst, nicht game.gd: es ist
## einer *pro Karte*, versetzt zum jeweiligen Flug, und wann eine Karte
## losfliegt, weiss nur die Hand. Beim Austeilen (oben) bleibt es bei einem Ton.
func _draw_into_hand(count: int) -> void:
	var drawn := _draw_cards(count)
	if drawn.is_empty():
		return
	%Hand.draw_in(drawn, energy)


# --- Zustand (kein Anfassen der Anzeige) -------------------------------------

## Zieht bis zu `count` Karten in die Hand und gibt zurueck, welche das waren.
##
## Nicht die Anzahl, sondern die Karten selbst: die Anzeige muss genau diese
## Karten auf den Tisch legen, und "es waren zwei" reicht dafuer nicht.
##
## Ohne refresh() - das machen die Aufrufer, sonst wird beim Ziehen von fuenf
## Karten fuenfmal unnoetig die Anzeige neu gerechnet.
func _draw_cards(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for i in count:
		var card := _draw_one()
		if card == null:
			break
		drawn.append(card)
	return drawn


## Zieht eine Karte. Sind Ziehstapel und Ablage beide leer, gibt es null -
## und dann soll auch kein Ziehgeraeusch kommen.
func _draw_one() -> CardData:
	if deck.is_empty():
		_reshuffle_discard()
	if deck.is_empty():
		return null
	var card: CardData = deck.pop_back()
	hand.append(card)
	return card


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
## Der Text kommt jetzt aus der Aktion selbst, statt hier aus Symbol und Zahl
## gebaut zu werden. Grund: "Mama!" hat eine Zahl, die nichts erklaert, und "Am
## Bein haengen" hat zwei verschiedene - eine Regel, die fuer beide passt, gibt
## es nicht. Wie eine Drohung formuliert ist, ist ohnehin Design und gehoert in
## die .tres.
##
## Ueber den Zahlen steht der Name der Aktion. Ohne ihn ist ein Herz mit einer 8
## daneben nur eine Regel; mit ihm ist es ein Kind, das nach der Mama schreit -
## und in einer Komoedie ist genau das der Inhalt. Der Name steht kleiner und
## blasser als die Zahlen: er erklaert, entschieden wird nach der Zahl.
func refresh_intent() -> void:
	var action := brain.intent
	if action == null or _game_over:
		%IntentLabel.text = ""
		return

	var values := Icons.fill(action.intent, action.intent_values())
	if action.action_name.is_empty():
		%IntentLabel.text = "[center]%s[/center]" % values
		return
	%IntentLabel.text = "[center]%s\n%s[/center]" % [INTENT_NAME_FORMAT % action.action_name, values]


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
	_end_game("Balg besiegt")


func _on_player_died() -> void:
	_end_game(defeat_title)


func _end_game(title: String) -> void:
	_game_over = true
	%EndTitle.text = title
	%EndOverlay.show()


func _on_retry_button_pressed() -> void:
	Sfx.play("click")
	get_tree().reload_current_scene()


## Nach Sieg oder Niederlage war der einzige Weg weiter der Neustart. Ein
## Endzustand, aus dem nur eine Tuer fuehrt, ist eine Sackgasse mit Aussicht.
func _on_menu_button_pressed() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
