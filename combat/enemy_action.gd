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

## Nur fuer Menschen: taucht im Inspector und in Logs auf, nirgends im Spiel.
## Eine .tres ohne Namen ist im Pattern-Array nicht von der naechsten zu
## unterscheiden.
@export var action_name: String = ""

## Wird der Reihe nach ausgefuehrt, wenn der Gegner am Zug ist.
## Was eine Wirkung *tut*, steht nicht hier, sondern in game.gd - siehe dort.
@export var effects: Array[CardEffect] = []

## Was ueber dem Gegner steht, bevor er handelt - als Schablone, nicht als
## abgetippte Zahl ("{icon_dmg} {damage}").
##
## Frueher baute game.gd diesen Text selbst zusammen, weil er immer "Symbol
## Zahl" war. Das stimmt nicht mehr: "Papa, bitte!" hat gar keine Zahl, "Am Bein
## haengen" hat zwei verschiedene. Welche Zahlen eine Aktion zeigt, weiss nur
## sie - wie ein Schadenssymbol aussieht, geht sie dagegen nichts an. Das legt
## die Anzeige dazu (Icons.fill).
##
## Absichtlich kein Vorschau-Automatismus, der aus der Effektliste einen Satz
## baut: die Drohung ist das Erste, was der Spieler jede Runde liest, und
## Formulierung ist dort Design, keine Ableitung.
@export_multiline var intent: String = ""


## Ob bei dieser Aktion etwas zuschlaegt - nur fuer die Tonspur.
##
## Ein Kind, das sich verkriecht, soll nicht klingen wie eine Ohrfeige. Die
## Alternative waere ein Ton pro Wirkung gewesen; bei "Schaden plus Entzug" sind
## das dann zwei Geraeusche fuer einen Zug, und das eine Ereignis auf dem
## Bildschirm zerfaellt akustisch in zwei.
func is_attack() -> bool:
	for effect in effects:
		if effect != null and effect.kind == CardEffect.Kind.SCHADEN:
			return true
	return false


## Die Zahlen fuer die Platzhalter in `intent`.
func intent_values() -> Dictionary:
	return CardEffect.values_from(effects)
