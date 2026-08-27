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
@export var type: Type = Type.ANGRIFF

## Wird der Reihe nach ausgefuehrt, wenn die Karte gespielt wird.
## Was eine Wirkung *tut*, steht nicht hier, sondern in game.gd - siehe dort.
@export var effects: Array[CardEffect] = []

@export_multiline var description: String = ""

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
