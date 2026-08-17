class_name CardEffect
extends Resource

## Eine einzelne Wirkung. Eine Karte hat eine Liste davon und tut sie der Reihe nach.
##
## Warum ein Enum und nicht je eine Klasse pro Wirkung (SchadenEffekt,
## BlockEffekt, ...)? Beide Wege funktionieren. Der Klassen-Weg ist offener -
## jede Wirkung bringt ihre eigenen Felder mit -, kostet dafuer pro Wirkung eine
## Datei, und das Ausfuehren verteilt sich ueber all diese Dateien. Bei sechs
## Wirkungen, die alle "eine Zahl" sind, steht so an einer Stelle etwas mehr,
## dafuer an sechs Stellen gar nichts.
##
## Umgestellt wird, sobald eine Wirkung Felder braucht, die die anderen nicht
## haben. Dann faengt `amount` an, je nach `kind` etwas anderes zu bedeuten -
## und genau da kippt ein Enum.
##
## Dieselbe Bauart wie EnemyAction, absichtlich: irgendwann ist eine
## Gegneraktion nur noch eine Liste von CardEffect, und dann rechnen beide
## Seiten des Tisches mit demselben Vokabular.
##
## KEIN `times`-Feld ("dreimal 3 Schaden"). Das war geplant und ist beim
## Nachrechnen gefallen: Block ist ein Vorrat, der aufgebraucht wird, nicht eine
## Reduktion pro Treffer. Gegen 2 Block kommen von 3x3 genau 7 durch - und von
## 1x9 ebenfalls 7. Mehrfachangriffe sind hier also *rechnerisch identisch* zum
## Einzelschlag, das Feld waere ein Regler ohne Wirkung. Es lohnt sich erst mit
## Staerke (addiert pro Treffer) oder Verwundbar (multipliziert pro Treffer).

enum Kind {
	SCHADEN,        # Schaden am Gegner
	BLOCK,          # Block fuer den Spieler
	HEILEN,         # Leben zurueck, hoechstens bis max_health
	ZIEHEN,         # Karten nachziehen, amount = Anzahl
	ENERGIE,        # Energie dazu, amount = Anzahl
	SELBSTSCHADEN,  # Schaden am Spieler selbst - der Preis starker Karten
}

@export var kind: Kind = Kind.SCHADEN

## Wie viel. Punkte bei SCHADEN/BLOCK/HEILEN/SELBSTSCHADEN,
## Anzahl bei ZIEHEN und ENERGIE.
@export var amount: int = 0
