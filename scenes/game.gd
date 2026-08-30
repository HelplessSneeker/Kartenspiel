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

## Der Gegner dieses Kampfes.
##
## Kommt aus dem Run, nicht aus dem Inspector. Bis zum Run-Umbau standen Leben,
## Muster und Niederlagentext als @export hier und wurden in game.tscn
## ausgefuellt - also am Kampfplatz statt am Gegner. Das ging, solange es einen
## Kampf gab; bei zweien haette game.tscn wissen muessen, wer gerade dran ist.
## Jetzt weiss es der Run, und die Szene fragt nach.
var foe: EnemyData

## Der Ziehstapel *dieses Kampfes* - eine Kopie von Run.deck, die beim Ziehen
## schrumpft. Das Deck des Runs bleibt davon unberuehrt.
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

## True, solange eine gespielte Karte zu ihrem Ziel unterwegs ist.
##
## Die Karte wirkt erst beim Einschlag, nicht beim Klick - genau darum geht es
## bei diesem Schritt. Zwischen beidem liegt ein knapper Moment, in dem der
## Zustand halb fertig ist: die Energie ist schon abgezogen, der Schaden noch
## nicht angekommen. Wer da eine zweite Karte spielen duerfte, koennte mit
## Energie bezahlen, die eine noch nicht gewirkte Karte gerade erst gibt.
##
## Zweite Sperre neben _game_over statt einer gemeinsamen: die beiden bedeuten
## Verschiedenes. _game_over ist endgueltig, das hier dauert zwei Zehntel.
var _resolving := false


func _ready() -> void:
	Music.play("battle")

	# Wer game.tscn direkt aus dem Editor startet (F6), kommt ohne Run hier an.
	# Dann faengt hier einer an, statt dass die Szene mit leerem Deck und ohne
	# Gegner dasteht. Sonst waere der Kampf nur noch ueber das Hauptmenue zu
	# erreichen - und eine Szene, die man nicht mehr einzeln starten kann, ist im
	# Alltag deutlich unangenehmer, als diese drei Zeilen kosten.
	if not Run.is_active() or Run.current_enemy() == null:
		Run.start_new()

	foe = Run.current_enemy()
	if foe == null:
		push_error("Kein Gegner fuer Kampf %d - run_config.tres pruefen." % Run.fight_number())
		# Sperren statt nur aussteigen. Ohne Gegner gibt es keinen `enemy`, und
		# der erste Klick auf "Zug beenden" liefe in einen Nullwert - ein zweiter
		# Fehler, der den ersten in der Konsole nach oben schiebt.
		_game_over = true
		return

	# Der Spieler tritt mit dem Leben an, das ihm der letzte Kampf gelassen hat.
	# Der Gegner faengt immer voll an - er ist neu, der Spieler nicht.
	player = Combatant.new(Run.max_health, Run.health)
	enemy = Combatant.new(foe.max_health)
	player.died.connect(_on_player_died)
	enemy.died.connect(_on_enemy_died)

	# Name und Bild erst jetzt, statt in game.tscn: die Anzeige gehoert zwar der
	# Szene, wen sie zeigt aber dem Run. Die Setter in HealthView schreiben
	# sofort durch, weil Kinder vor ihrem Elternknoten bereit sind.
	%EnemyView.title = foe.display_name
	%EnemyView.portrait = foe.portrait
	%PlayerView.show_combatant(player)
	%EnemyView.show_combatant(enemy)
	%FightLabel.text = "Kampf %d/%d" % [Run.fight_number(), Run.fight_count()]

	brain = EnemyBrain.new(foe.pattern)
	%Hand.card_clicked.connect(play_card)

	deck = Run.deck.duplicate()
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
	# Auch der Zugwechsel wartet, bis die Karte eingeschlagen ist. Sonst
	# schluege der Gegner zu, waehrend die eigene Watschn noch fliegt - und der
	# Block, den man gerade gespielt hat, waere noch nicht da, wenn er trifft.
	if _game_over or _resolving:
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
	if _game_over or _resolving:
		return
	var card_data := view.data
	# Zwei Absagen, ein Geraeusch. Ein eigener Ton fuer "geht nie" waere ehrlicher,
	# aber es gibt ihn noch nicht - und die Karte sagt es ohnehin selbst: grauer
	# Rahmen, kein Preis, "Unspielbar" im Text.
	if not card_data.is_playable() or card_data.cost > energy:
		Sfx.play("error")
		return

	# Das Legegeraeusch nur fuer Karten ohne eigenen Ton.
	#
	# Vorher lief beides: hier das Legen, beim Einschlag der Kartenton. Gedacht war
	# das als zwei Ereignisse - Karte verlaesst die Hand, Karte kommt an -, gehoert
	# hat es sich aber nach Doppelung (Befund bfn, 27.08.2026). Bei einem
	# Kartenflug von zwei Zehnteln liegen die beiden Geraeusche zu dicht
	# beieinander, um als zwei gelesen zu werden.
	#
	# Der eigene Ton gewinnt, weil er mehr sagt: dass eine Watschn geflogen ist,
	# ist die Information - dass dabei ein Stueck Karton bewegt wurde, nicht.
	if card_data.sound.is_empty():
		Sfx.play("card_play")
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

	# Zweimal anzeigen, einmal hier und einmal nach dem Einschlag. Die Energie
	# ist *jetzt* weg, und die uebrigen Karten muessen sofort grau werden - eine
	# Anzeige, die zwei Zehntel hinterherhinkt, liest sich als Ruckler.
	refresh()

	# Ab hier ist eine Karte unterwegs und das Spiel nimmt nichts mehr an.
	_resolving = true
	%Hand.play_out(view, _strike_target(card_data))
	await %Hand.card_struck
	_resolving = false

	# Nach einem await ist nichts mehr selbstverstaendlich: in der Zwischenzeit
	# kann die Szene gewechselt haben (Pausenmenue -> Hauptmenue), und dann
	# haengt dieser Ablauf an einem Knoten, den es nicht mehr gibt.
	if not is_inside_tree() or _game_over:
		return

	if not card_data.sound.is_empty():
		Sfx.play(card_data.sound)

	for effect in card_data.effects:
		_apply_effect(effect, player, enemy)
		# Eine Karte kann beide Seiten toeten (Aderlass gegen einen Gegner mit
		# 5 Leben). Was danach in der Liste steht, darf dann nicht mehr wirken.
		if _game_over:
			break

	refresh()


## Wohin die gespielte Karte fliegt.
##
## game.gd sagt nur, *wer* getroffen wird, und liefert die Mitte von dessen
## Anzeige; wo dieser Punkt in Hand-Koordinaten liegt, rechnet die Hand selbst
## aus. Die Aufteilung ist dieselbe wie ueberall hier: die Spiellogik kennt die
## Beteiligten, die Anzeige kennt ihre eigenen Koordinaten.
func _strike_target(card_data: CardData) -> Vector2:
	var target: Control = %EnemyView if card_data.hits_enemy() else %PlayerView
	return target.get_global_rect().get_center()


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
## selbst. Damit ist "Lecker Bierchen" beim Spieler und "WIESOOOO!" beim Sohn
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
## Kampf gewonnen - und damit entweder der Run oder nur eine Etappe.
##
## Das uebrige Leben geht hier an den Run zurueck. Genau dieser Uebertrag ist
## der Unterschied zwischen einer Reihe Einzelkaempfe und einem Durchlauf: ohne
## ihn waere jeder Treffer, den man kassiert hat, ab dem Siegbildschirm
## folgenlos - man koennte sich durch jeden Kampf pruegeln lassen, solange man
## ihn am Ende gewinnt.
func _on_enemy_died() -> void:
	Run.win_fight(player.health)
	if Run.is_finished():
		_end_game(Run.victory_title(), false)
		return
	_end_game(foe.victory_title, true)


func _on_player_died() -> void:
	_end_game(foe.defeat_title, false)


## `has_next` sagt, ob der Run weitergeht. Danach richtet sich, welcher Knopf im
## Overlay steht: mitten im Run ist "Weiter" die einzige sinnvolle Fortsetzung,
## am Ende ist es "Nochmal". Beide gleichzeitig zu zeigen hiesse, den Spieler zu
## fragen, ob er den gerade gewonnenen Kampf lieber nochmal von vorn haette.
func _end_game(title: String, has_next: bool) -> void:
	_game_over = true
	%EndTitle.text = title
	%NextButton.visible = has_next
	%RetryButton.visible = not has_next
	%EndOverlay.show()


## Der naechste Kampf ist dieselbe Szene neu geladen. Wer der Gegner ist, steht
## im Run - win_fight() ist dort schon einen weitergerueckt.
##
## Neu laden statt die Szene im Betrieb umzuruesten: ein Kampf hinterlaesst
## laufende Tweens, Karten auf dem Weg zur Ablage und ein Dutzend verbundene
## Signale. Die einzeln zurueckzusetzen ist eine Liste, von der man immer genau
## einen Punkt vergisst - und der faellt dann drei Kaempfe spaeter auf.
func _on_next_button_pressed() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


## "Nochmal" heisst jetzt: neuer Run, nicht derselbe Kampf noch einmal.
##
## Vorher stand hier reload_current_scene(), und das war richtig, solange ein
## Kampf das ganze Spiel war. Jetzt waere es eine Falle: die Szene laedt neu,
## der Run-Zustand bleibt aber stehen - man traete den verlorenen Kampf mit dem
## Leben an, mit dem man gerade gestorben ist, also mit null.
func _on_retry_button_pressed() -> void:
	Sfx.play("click")
	Run.start_new()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


## Nach Sieg oder Niederlage war der einzige Weg weiter der Neustart. Ein
## Endzustand, aus dem nur eine Tuer fuehrt, ist eine Sackgasse mit Aussicht.
func _on_menu_button_pressed() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
