extends Resource
class_name CardData

## Was eine Karte ist: Name, Preis, Art - und eine Liste von Wirkungen.
##
## `damage` und `block` als eigene Felder sind weggefallen. Sie waren die
## Annahme, eine Karte koenne genau diese zwei Dinge tun; jede weitere Wirkung
## haette ein weiteres Feld gebraucht, das bei fast jeder Karte 0 ist. Die Liste
## kostet dafuer etwas mehr Umstand pro .tres, traegt aber alles, was noch kommt.

## Wofuer die Karte da ist. Faerbt den Rahmen - und seit STATUS auch eine Regel.
##
## Hiess vorher `Category { AKTION, REAKTION }` und stammte aus dem reaktiven
## Stack-Modell: Karte legen, Gegner antwortet darauf. Gebaut ist ein Zugmodell
## nach Slay-the-Spire-Art, in dem es keine Reaktion gibt - das Feld beschrieb
## also eine Regel, die es nicht gibt, und "Reaktion" auf einer Karte war eine
## Zusage, die das Spiel nicht einhaelt.
##
## STATUS ist die Karte, die einem *zugeschoben* wird und nichts tut. Sie kostet
## keine Energie und laesst sich nicht spielen; ihr ganzer Effekt ist, dass sie
## einen der fuenf Handplaetze belegt. Warum ein Kartentyp und kein zusaetzliches
## `playable`-Feld: unspielbar zu sein ist keine Eigenschaft, die man einer
## Angriffskarte ankreuzen wollen wuerde - es ist eine eigene Art von Karte, und
## Type entscheidet ohnehin schon, wie sie aussieht.
##
## ZUR ZEIT OHNE NUTZER. Gebaut fuer das Kind ("Papierl", eine Karte, die es
## einem ins Deck schiebt) und wieder herausgenommen: eine Karte, die erst zwei
## Mischvorgaenge spaeter auffaellt, hat keinen Moment, in dem der Witz landet -
## und das Spiel lebt vom Sofortigen. Der Weg bleibt trotzdem stehen, weil das
## Design-Doc ihn fuer die starken Biere vorsieht ("Doppelter Draggelsberger":
## viel Block, dafuer Deck-Verschmutzung). Dort ist die Verzoegerung kein
## Problem, sondern der Preis, den man selbst waehlt.
enum Type { ANGRIFF, VERTEIDIGUNG, FERTIGKEIT, STATUS }

@export var card_name: String = ""
@export var cost: int = 0

## Um wie viel die Karte nach jedem Ausspielen teurer wird. 0 heisst: sie kostet
## immer dasselbe, also bei allen ausser Schem Schem.
##
## Der *Aufschlag* steht bewusst nicht hier, sondern in game.gd. Grund: eine
## CardData ist im ganzen Projekt geteilt und zur Laufzeit unveraendert - das
## Startdeck haelt Watschn fuenfmal als denselben Verweis, und play_card()
## verlaesst sich darauf. Wuerde eine gespielte Karte ihr eigenes `cost`
## hochzaehlen, waere das der erste Ort, an dem eine Resource sich im Spiel
## veraendert; der Aufschlag ueberlebte den Kampf, das Hauptmenue und einen
## Neustart des Runs, denn Godot laedt eine .tres genau einmal.
##
## Also: die Karte sagt, *dass* sie teurer wird und um wie viel pro Mal. Wie oft
## das schon passiert ist, weiss der laufende Kampf - und vergisst es, wenn er
## endet. Damit ist der Aufschlag automatisch pro Kampf und nicht pro Run, weil
## jeder Kampf die Szene neu laedt.
@export var cost_growth: int = 0

@export var type: Type = Type.ANGRIFF

## Wird der Reihe nach ausgefuehrt, wenn die Karte gespielt wird.
## Was eine Wirkung *tut*, steht nicht hier, sondern in game.gd - siehe dort.
@export var effects: Array[CardEffect] = []

@export_multiline var description: String = ""

## Welches Geraeusch das Ausspielen macht - ein Ereignisname fuer `Sfx.play()`,
## kein Dateipfad. Leer laesst es beim allgemeinen Kartenlegeton.
##
## Steht hier bereit, ist aber noch bei keiner Karte gesetzt: das Legegeraeusch
## passt zu allem, was einfach eine Karte ist. Interessant wird das Feld bei
## denen, die etwas Bestimmtes *tun* - eine Watschn sollte nach Watschn klingen
## und nicht nach Karton.
@export var sound: String = ""

## Das Bild auf der Karte. Darf leer bleiben - Karten ohne Bild zeigen einfach
## keins, statt ein Loch im Layout zu lassen (siehe card.gd).
##
## Bewusst ein Texture2D und kein Pfad-String: so haengt die Datei am
## Resource-System. Godot laedt sie mit der Karte, der Editor zeigt sie im
## Inspector, und ein Tippfehler faellt beim Import auf statt erst zur Laufzeit.
##
## Wie das Bild *zugeschnitten* wird, steht nicht hier, sondern im ArtRect in
## card.tscn - das ist Darstellung, keine Karteneigenschaft.
@export var art: Texture2D


## Ob die Karte ueberhaupt gespielt werden kann.
##
## Steht als eigene Methode da und nicht als `type != Type.STATUS` an den drei
## Stellen, die es wissen wollen (game.gd beim Klick, hand.gd zweimal beim
## Einfaerben). Sobald es einen zweiten Grund gibt, unspielbar zu sein -
## "verbrannt", "eingefroren" -, ist das hier eine Zeile statt einer Suche.
func is_playable() -> bool:
	return type != Type.STATUS


## Ob die Karte auf den Gegner zielt - sonst auf den Spieler selbst.
##
## Entscheidet, wohin die Karte beim Ausspielen fliegt. Abgeleitet aus den
## Wirkungen und nicht aus `type`, obwohl das kuerzer waere: `type` faerbt den
## Rahmen und ist ansonsten eine Behauptung, die niemand prueft. Eine
## Fertigkeitskarte, die Schaden macht, wuerde damit auf den eigenen Spieler
## einschlagen - und der Fehler saehe aus wie ein Animationsfehler, waere aber
## ein falsch gesetztes Feld in einer .tres.
##
## Dieselbe Regel wie in _apply_effect(): wohin etwas geht, entscheidet die Art
## der Wirkung. Karte und Wirkung koennen so nicht auseinanderlaufen.
##
## Bei gemischten Karten ("8 Schaden und 3 Selbstschaden") gewinnt der Angriff:
## der Selbstschaden ist der Preis, nicht der Punkt.
func hits_enemy() -> bool:
	for effect in effects:
		if effect == null:
			continue
		if effect.kind == CardEffect.Kind.SCHADEN:
			return true
		# Auch dann, wenn die Zahl gerade 0 ergibt: Watschen Bam ohne Watschn auf
		# der Hand macht keinen Schaden, ist aber trotzdem ein Schlag und fliegt
		# zum Gegner. Wohin eine Karte zielt, darf nicht davon abhaengen, wie die
		# Hand in diesem Moment aussieht - sonst landet dieselbe Karte mal links
		# und mal rechts, und das liest sich als Fehler.
		if effect.kind == CardEffect.Kind.SCHADEN_PRO_KARTE:
			return true
	return false


## Die Zahlen fuer die Platzhalter im Kartentext.
##
## Der Text auf der Karte ist eine Schablone ("{icon_dmg} {damage} Schaden"),
## keine abgetippte Zahl - dadurch koennen Text und Regel nicht auseinander
## laufen. Nur die Karte weiss, was sie tut; wie ein Schadenssymbol aussieht,
## geht sie dagegen nichts an - die `{icon_*}` legt die Anzeige dazu
## (Icons.fill).
##
## Das Zusammensammeln selbst liegt seit dem Kind-Moveset in CardEffect: der
## Gegner-Intent fuellt dieselben Platzhalter aus derselben Art Liste. Die
## Methode hier bleibt trotzdem stehen, damit die Anzeige weiterhin die *Karte*
## nach ihren Zahlen fragt und nicht deren Innereien auseinandernimmt.
func description_values() -> Dictionary:
	return CardEffect.values_from(effects)
