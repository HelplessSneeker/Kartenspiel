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

## Die drei Signale unten sagen, *was* passiert ist - `changed` sagt nur, *dass*
## etwas passiert ist.
##
## Der Unterschied ist der ganze Grund, warum es sie gibt. Zum Neuzeichnen
## genuegt "irgendwas ist anders": die Anzeige liest danach einfach alle Werte
## neu. Fuer Rueckmeldung genuegt das nicht - ein Balken, der von 42 auf 37
## springt, zeigt nicht, dass gerade 5 Schaden angekommen sind, er zeigt nur den
## Zustand danach. Die Zahl, die kurz aufsteigt, muss jemand mitliefern, und
## kennen tut sie nur die Stelle, die gerechnet hat.
##
## Die Alternative waere gewesen, die Anzeige alte und neue Werte selbst
## vergleichen zu lassen. Das haette funktioniert, aber sie muesste daraus
## *erraten*, was passiert ist - und "Block ist um 5 gefallen" heisst je nach
## Zusammenhang "getroffen" oder "Runde vorbei, Block verfaellt". Solche
## Unterscheidungen gehoeren nicht in eine Anzeige.

## Ein Treffer ist angekommen. `health_lost` ging ans Leben, `block_lost` hat
## der Block geschluckt - getrennt, weil die Anzeige beides verschieden zeigt.
## Feuert auch, wenn der Block alles abgefangen hat (health_lost == 0).
signal damaged(health_lost: int, block_lost: int)

## Leben zurueck. `amount` ist, was wirklich ankam, nicht was versucht wurde -
## eine Heilung ueber das Maximum hinaus soll keine Zahl zeigen, die es nicht gab.
signal healed(amount: int)

## Block dazu. Nicht beim Verfallen - das ist keine Rueckmeldung auf eine
## Handlung, sondern Rundenwechsel.
signal blocked(amount: int)

var max_health: int
var health: int

## Faengt Schaden ab, bevor er ans Leben geht. Haelt genau eine Runde: wer ihn
## setzt, ruft clear_block() zu Beginn seines naechsten eigenen Zuges - also
## erst, nachdem der Gegenangriff durch war, gegen den geblockt wurde.
var block: int = 0


## `starting_health` ist fuer den Spieler im zweiten Kampf eines Runs da: er
## tritt mit dem an, was ihm vom ersten geblieben ist, nicht wieder voll.
##
## Warum -1 als "nicht angegeben" und nicht 0? Weil 0 ein gueltiger Wert ist -
## ein Kaempfer mit 0 Leben ist tot, und das soll man bauen koennen (und sei es
## nur, um zu sehen, dass das Spiel es merkt). Eine Vorgabe muss ausserhalb des
## Wertebereichs liegen, sonst verschluckt sie einen echten Fall.
func _init(new_max_health: int, starting_health := -1) -> void:
	max_health = maxi(new_max_health, 1)
	health = max_health if starting_health < 0 else clampi(starting_health, 0, max_health)


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
	var lost := amount - absorbed
	health = maxi(health - lost, 0)

	# changed zuerst: die Anzeige soll die neuen Werte schon stehen haben, wenn
	# die Zahl darueber losfliegt. Sonst steigt eine -5 auf, waehrend der Balken
	# noch den Stand von davor zeigt.
	changed.emit()
	damaged.emit(lost, absorbed)
	if health == 0:
		died.emit()


func add_block(amount: int) -> void:
	if amount <= 0:
		return
	block += amount
	changed.emit()
	blocked.emit(amount)


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
	# Was wirklich ankommt, kann weniger sein als `amount`: bei 48 von 50 heilen
	# 8 Punkte nur noch 2. Die Anzeige soll die 2 zeigen, nicht die 8 - eine
	# Zahl, die groesser ist als der Ausschlag im Balken, macht die Anzeige
	# unglaubwuerdig.
	var gained := mini(amount, max_health - health)
	health += gained
	changed.emit()
	healed.emit(gained)


## Wird zu Rundenbeginn gerufen: Block haelt nur eine Runde.
func clear_block() -> void:
	if block == 0:
		return
	block = 0
	changed.emit()


func is_alive() -> bool:
	return health > 0
