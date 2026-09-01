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

## Woraus die Belohnung nach einem gewonnenen Kampf gezogen wird.
##
## Getrennt vom Startdeck, obwohl beides Listen von Karten sind: das Startdeck
## sagt, womit man anfaengt, der Pool, was man werden kann. Eine Karte darf in
## beiden stehen - dann bekommt man eine zweite davon - oder nur hier. Zirbn,
## Watschen Bam und Schem Schem sind genau dieser Fall und sonst nirgends
## erreichbar.
##
## Leer heisst: keine Belohnung, der Endbildschirm sieht aus wie vorher. Das ist
## kein Fehlerfall, sondern der Weg, das Ganze abzuschalten.
@export var reward_pool: Array[CardData] = []

## Wie viele Karten nach einem Sieg zur Auswahl stehen.
##
## Drei, weil zwei keine Entscheidung sind - man nimmt die bessere - und vier
## den Endbildschirm breiter machen, als ein 720p-Fenster vertraegt. Steht
## trotzdem im Inspector: was sich ohne Code aendern laesst, gehoert in die .tres.
@export var reward_choices := 3

@export var player_max_health := 50

## Was ueber dem Bildschirm steht, wenn *alle* Gegner gefallen sind.
##
## Der Satz gehoert dem Run und nicht dem letzten Gegner: er sagt, dass der
## Durchlauf vorbei ist, nicht dass jemand umgefallen ist. Faende er in
## enemies.back() statt hier, wuerde er falsch, sobald ein Gegner dazukommt.
@export var victory_title := "Du bist draussen"
