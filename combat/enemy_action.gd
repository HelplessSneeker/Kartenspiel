class_name EnemyAction
extends Resource

## Was der Gegner in einem Zug tut.
##
## Bewusst dieselbe Bauart wie CardData: Daten in einer .tres, keine Logik.
## Ein neues Gegner-Verhalten ist damit eine neue Datei und ein Eintrag im
## Inspector - kein Code. Genau die Zusage aus dem Design-Doc ("Karten = Daten"),
## nur auf die andere Seite des Tisches angewandt.
##
## Kein `description`-Template wie bei CardData: der Text ueber dem Gegner ist
## immer "Symbol Zahl" und haengt an nichts, was sich pro Aktion aendert.
## Gebaut wird er deshalb dort, wo angezeigt wird - in game.gd.

enum Kind { ANGRIFF, BLOCK }

@export var kind: Kind = Kind.ANGRIFF

## Schaden bei ANGRIFF, Block bei BLOCK. Eine Zahl reicht, solange eine Aktion
## genau eine Sache tut. Sobald das nicht mehr stimmt, ist das der Moment fuer
## dasselbe Effekt-System, das auch die Karten irgendwann brauchen.
@export var amount: int = 0
