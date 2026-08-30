class_name RunConfig
extends Resource

## Wie ein Durchlauf aussieht: womit man startet und gegen wen man antritt.
##
## Warum eine Resource und kein Autoload mit @export? Weil die Werte eines
## Autoload-Skripts im Editor nirgends auftauchen - ein Autoload ist ein Knoten,
## den niemand anklicken kann, und sein Inspector existiert nicht. Als .tres
## laesst sich der Run zusammenklicken wie eine Karte, und der Zustand
## (run_state.gd) bleibt reiner Zustand.
##
## Damit ist "ein zweiter Gegner" ein Eintrag in `enemies` und "eine
## Startkarte mehr" ein Eintrag in `starting_deck` - beides ohne Code.

## Das Deck, mit dem jeder Run anfaengt.
##
## Zog frueher als @export in game.tscn, also *pro Kampf*. Das war richtig,
## solange ein Kampf das ganze Spiel war; jetzt waere es falsch: das Deck soll
## einen Kampf ueberleben und spaeter zwischen den Kaempfen wachsen.
@export var starting_deck: Array[CardData] = []

## Die Gegner in der Reihenfolge, in der sie drankommen.
@export var enemies: Array[EnemyData] = []

@export var player_max_health := 50

## Was ueber dem Bildschirm steht, wenn *alle* Gegner gefallen sind.
##
## Der Satz gehoert dem Run und nicht dem letzten Gegner: er sagt, dass der
## Durchlauf vorbei ist, nicht dass jemand umgefallen ist. Faende er in
## enemies.back() statt hier, wuerde er falsch, sobald ein Gegner dazukommt.
@export var victory_title := "Du bist draussen"
