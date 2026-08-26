class_name Combatant
extends RefCounted

## Ein Kaempfer: Leben, Block, sonst nichts. Kennt weder Karten noch Anzeige.
##
## Bewusst RefCounted und kein Node: ein Kaempfer ist Zustand, kein Ding im
## Szenenbaum. Die Anzeige (HealthView) haengt sich per Signal dran, statt dass
## die Logik eine Anzeige besitzt - dieselbe Richtung wie bei Hand/CardView.

## Feuert nach jeder Aenderung an Leben oder Block. Wer anzeigt, hoert zu.
signal changed

## Feuert genau einmal, wenn das Leben auf 0 faellt.
signal died

var max_health: int
var health: int

## Faengt Schaden ab, bevor er ans Leben geht. Haelt genau eine Runde: wer ihn
## setzt, ruft clear_block() zu Beginn seines naechsten eigenen Zuges - also
## erst, nachdem der Gegenangriff durch war, gegen den geblockt wurde.
var block: int = 0


func _init(new_max_health: int) -> void:
	max_health = maxi(new_max_health, 1)
	health = max_health


## Schaden geht erst gegen den Block, der Rest ans Leben.
##
## Auf einen bereits Toten passiert nichts mehr. Ohne diese Abfrage wuerde
## `died` bei jedem weiteren Treffer erneut feuern, und die Zusage im Signal -
## genau einmal - haengt sonst daran, dass jeder Aufrufer vorher is_alive()
## prueft. Solche Zusagen gehoeren an die Stelle, die sie halten kann.
func take_damage(amount: int) -> void:
	if amount <= 0 or health == 0:
		return

	var absorbed := mini(block, amount)
	block -= absorbed
	health = maxi(health - (amount - absorbed), 0)

	changed.emit()
	if health == 0:
		died.emit()


func add_block(amount: int) -> void:
	if amount <= 0:
		return
	block += amount
	changed.emit()


## Leben zurueck, aber nie ueber das Maximum.
##
## Auf einen Toten wirkt nichts mehr - dieselbe Sperre wie in take_damage().
## Ohne sie koennte eine Karte, die Schaden *und* Heilung macht, den Spieler
## in derselben Zeile toeten und wiederbeleben: `died` waere gefeuert, das
## Spiel vorbei, die Anzeige zeigte aber wieder Leben. Ein Endzustand, der sich
## zuruecknehmen laesst, ist keiner.
func heal(amount: int) -> void:
	if amount <= 0 or health == 0 or health == max_health:
		return
	health = mini(health + amount, max_health)
	changed.emit()


## Wird zu Rundenbeginn gerufen: Block haelt nur eine Runde.
func clear_block() -> void:
	if block == 0:
		return
	block = 0
	changed.emit()


func is_alive() -> bool:
	return health > 0
