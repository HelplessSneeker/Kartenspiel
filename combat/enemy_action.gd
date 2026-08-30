class_name EnemyAction
extends Resource

## Was der Gegner in einem Zug tut.
##
## Bewusst dieselbe Bauart wie CardData: Daten in einer .tres, keine Logik.
## Ein neues Gegner-Verhalten ist damit eine neue Datei und ein Eintrag im
## Inspector - kein Code. Genau die Zusage aus dem Design-Doc ("Karten = Daten"),
## nur auf die andere Seite des Tisches angewandt.
##
## `kind` und `amount` sind weg. Sie waren die Annahme, eine Gegneraktion tue
## genau eine Sache - schlagen *oder* blocken. Das Kind bricht die: es haengt am
## Bein (Schaden *und* Energieentzug) und bettelt (schiebt eine Karte ins Deck,
## ohne zu schlagen). Der alte Kommentar hier hat den Moment angekuendigt, an
## dem "dasselbe Effekt-System wie die Karten" faellig wird. Er ist da.

## Wie die Aktion heisst - steht ueber der angekuendigten Drohung.
##
## War zuerst nur eine Inspector-Hilfe ("eine .tres ohne Namen ist im
## Pattern-Array nicht von der naechsten zu unterscheiden"). Das reichte,
## solange der Gegner schlug oder blockte und die Zahl alles sagte. Jetzt heult,
## klammert, ruft und schmollt er - und ein Herz mit einer 8 daneben erklaert
## nicht, dass das Kind gerade nach der Mama schreit. Der Name ist bei diesem
## Gegner der halbe Inhalt.
@export var action_name: String = ""

## Welches Geraeusch die Aktion macht - ein Ereignisname fuer `Sfx.play()`,
## kein Dateipfad.
##
## Die Trennung ist dieselbe wie ueberall hier: die .tres sagt, *was* passiert
## ist, das Sfx-Autoload entscheidet, *wie* es klingt. Ein Tausch der Datei
## beruehrt dann eine Zeile in sfx_player.gd statt jeder Aktion, die sie nutzt.
##
## Leer heisst stumm. Solange die Dateien fehlen, ist es das auch mit Eintrag -
## und das ist die ehrlichere Anzeige als ein geliehenes Kartengeraeusch, das
## klingt, als waere es gemeint.
@export var sound: String = ""

## Wird der Reihe nach ausgefuehrt, wenn der Gegner am Zug ist.
## Was eine Wirkung *tut*, steht nicht hier, sondern in game.gd - siehe dort.
@export var effects: Array[CardEffect] = []

## Was ueber dem Gegner steht, bevor er handelt - als Schablone, nicht als
## abgetippte Zahl ("{icon_dmg} {damage}").
##
## Frueher baute game.gd diesen Text selbst zusammen, weil er immer "Symbol
## Zahl" war. Das stimmt nicht mehr: "MAMA!" zeigt eine Zahl, die nichts ueber
## den Spieler sagt (der Gegner heilt sich), "PAPA BITTE!" zeigt zwei
## verschiedene. Welche Zahlen eine Aktion zeigt, weiss nur sie - wie ein
## Schadenssymbol aussieht, geht sie dagegen nichts an. Das legt die Anzeige
## dazu (Icons.fill).
##
## Absichtlich kein Vorschau-Automatismus, der aus der Effektliste einen Satz
## baut: die Drohung ist das Erste, was der Spieler jede Runde liest, und
## Formulierung ist dort Design, keine Ableitung.
@export_multiline var intent: String = ""


## Die Zahlen fuer die Platzhalter in `intent`.
func intent_values() -> Dictionary:
	return CardEffect.values_from(effects)
