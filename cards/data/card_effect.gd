class_name CardEffect
extends Resource

## Eine einzelne Wirkung. Eine Karte hat eine Liste davon und tut sie der Reihe nach.
##
## Seit dem Kind-Moveset gilt das nicht mehr nur fuer Karten: EnemyAction haelt
## dieselbe Liste. Beide Seiten des Tisches rechnen jetzt mit demselben
## Vokabular - genau das, was der alte Kommentar hier angekuendigt hat. Der
## Preis dafuer steht in game.gd: eine Wirkung weiss nicht mehr von sich aus,
## wer Spieler und wer Gegner ist, das bekommt sie beim Ausfuehren gesagt.
##
## Warum ein Enum und nicht je eine Klasse pro Wirkung (SchadenEffekt,
## BlockEffekt, ...)? Beide Wege funktionieren. Der Klassen-Weg ist offener -
## jede Wirkung bringt ihre eigenen Felder mit -, kostet dafuer pro Wirkung eine
## Datei, und das Ausfuehren verteilt sich ueber all diese Dateien.
##
## UMSTELLUNGS-VERSPRECHEN EINGELOEST? Noch nicht. Hier stand: "Umgestellt wird,
## sobald eine Wirkung Felder braucht, die die anderen nicht haben." Mit
## KARTE_ZUSCHIEBEN ist dieser Fall da - die Wirkung braucht `card`, alle anderen
## nicht. Trotzdem bleibt das Enum, und das ist eine bewusste Abweichung:
##
## Der eigentliche Gewinn der Klassen-Loesung waere, dass jede Wirkung sich
## selbst ausfuehrt. Dafuer braeuchte sie Zugriff auf den ganzen Kampf (beide
## Kaempfer, Ziehstapel, Hand, Energie), also ein Kontext-Objekt, das man ihr
## reicht. Das ist ein groesserer Umbau als das Kind-Moveset rechtfertigt, und
## ohne ihn waeren acht Klassen nur acht Dateien mit je zwei Feldern, waehrend
## das match() in game.gd unveraendert stehen bliebe. Ein Feld, das bei sieben
## von acht Wirkungen leer ist, ist billiger als das.
##
## Naechster Ausloeser: sobald eine *zweite* Wirkung eigene Felder will. Dann
## Battle-Kontext bauen und richtig aufteilen, nicht wieder ein Feld anhaengen.
##
## KEIN `times`-Feld ("dreimal 3 Schaden"). Das war geplant und ist beim
## Nachrechnen gefallen: Block ist ein Vorrat, der aufgebraucht wird, nicht eine
## Reduktion pro Treffer. Gegen 2 Block kommen von 3x3 genau 7 durch - und von
## 1x9 ebenfalls 7. Mehrfachangriffe sind hier also *rechnerisch identisch* zum
## Einzelschlag, das Feld waere ein Regler ohne Wirkung. Es lohnt sich erst mit
## Staerke (addiert pro Treffer) oder Verwundbar (multipliziert pro Treffer).

## Die Reihenfolge ist Datenformat, nicht Geschmack: in den .tres steht die Zahl,
## nicht der Name. Neue Wirkungen kommen deshalb immer *hinten* dazu - wer
## dazwischenschiebt, aendert rueckwirkend jede gespeicherte Karte.
enum Kind {
	SCHADEN,           # Schaden am Gegenueber
	BLOCK,             # Block fuer den, der wirkt
	HEILEN,            # Leben zurueck, hoechstens bis max_health
	ZIEHEN,            # Karten nachziehen, amount = Anzahl
	ENERGIE,           # Energie dazu, amount = Anzahl
	SELBSTSCHADEN,     # Schaden an dem, der wirkt - der Preis starker Karten
	ENERGIE_ENTZUG,    # amount Energie weniger im naechsten Spielerzug
	KARTE_ZUSCHIEBEN,  # `card` amount-mal auf die Ablage des Spielers - z.Z. ungenutzt
}

@export var kind: Kind = Kind.SCHADEN

## Wie viel. Punkte bei SCHADEN/BLOCK/HEILEN/SELBSTSCHADEN, Anzahl bei ZIEHEN,
## ENERGIE, ENERGIE_ENTZUG und KARTE_ZUSCHIEBEN.
@export var amount: int = 0

## Nur fuer KARTE_ZUSCHIEBEN: welche Karte zugeschoben wird.
##
## Warum `Resource` und nicht `CardData`? Weil CardData bereits
## `Array[CardEffect]` haelt. Ein Typ-Verweis zurueck auf CardData waere ein
## gegenseitiger Script-Verweis, und der ist in Godot je nach Version eine
## "Cyclic reference" beim Parsen - ein Fehler, den ich hier nicht ausprobieren
## kann (kein Editor auf meiner Seite). `Resource` haelt es garantiert
## uebersetzbar; der Inspector zeigt dafuer jede Resource statt nur Karten.
##
## Wenn Godot 4.7 den engen Typ akzeptiert, ist das eine Zeile: `CardData`
## eintragen, Projekt neu laden, fertig. Probier es ruhig aus.
@export var card: Resource


## Sammelt die Zahlen aus einer Effektliste fuer die Platzhalter in Texten.
##
## Lag frueher in CardData. Weggezogen, als EnemyAction dieselbe Liste bekam:
## der Gegner-Intent fuellt genau dieselben Platzhalter aus genau denselben
## Wirkungen. Was zwei Besitzer hat, gehoert keinem von beiden - also hierher,
## zu dem Ding, das die Zahlen ueberhaupt haelt.
##
## Bei mehreren Wirkungen derselben Art gewinnt die erste. Etwas, das zweimal
## auf verschiedene Weise Schaden macht, braucht ohnehin einen eigenen Text und
## keinen Platzhalter.
##
## Alle Schluessel sind immer da, notfalls mit 0: ein Platzhalter, den niemand
## fuellt, laesst format() sonst als rohes "{damage}" im Text stehen.
static func values_from(effects: Array[CardEffect]) -> Dictionary:
	var values := {
		"damage": 0,
		"block": 0,
		"heal": 0,
		"draw": 0,
		"energy": 0,
		"self_damage": 0,
		"drain": 0,
		"push": 0,
	}
	var filled := {}
	for effect in effects:
		if effect == null:
			continue
		var key := _value_key(effect.kind)
		if key == "" or filled.has(key):
			continue
		filled[key] = true
		values[key] = effect.amount
	return values


## Welcher Platzhalter welche Wirkung meint. Die Namen hier sind das, was in den
## .tres in geschweiften Klammern steht.
static func _value_key(kind_value: Kind) -> String:
	match kind_value:
		Kind.SCHADEN:
			return "damage"
		Kind.BLOCK:
			return "block"
		Kind.HEILEN:
			return "heal"
		Kind.ZIEHEN:
			return "draw"
		Kind.ENERGIE:
			return "energy"
		Kind.SELBSTSCHADEN:
			return "self_damage"
		Kind.ENERGIE_ENTZUG:
			return "drain"
		Kind.KARTE_ZUSCHIEBEN:
			return "push"
		_:
			return ""
