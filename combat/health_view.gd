class_name HealthView
extends PanelContainer

## Zeigt einen Combatant an: Name, Lebensbalken, Zahl, Block.
##
## Die Knoten stehen in health_view.tscn, das Aussehen im Theme. Vorher baute
## dieses Skript seine Kinder selbst und trug seine Farben als Konstanten - das
## war richtig, solange es kein Theme gab. Jetzt gibt es eins, und Farben an
## zwei Orten zu pflegen ist genau der Zustand, den Session 1 aufgeraeumt hat.

## Beschriftung ueber dem Balken. Steht im Inspector, damit dasselbe Skript und
## dieselbe Szene fuer Spieler und Gegner reichen.
@export var title: String = "":
	set(value):
		title = value
		# Der Setter laeuft beim Laden der Szene, also vor _ready(). Zu dem
		# Zeitpunkt gibt es %TitleLabel noch nicht - _ready() holt es nach.
		if is_node_ready():
			%TitleLabel.text = title

var _combatant: Combatant


func _ready() -> void:
	%TitleLabel.text = title
	_refresh()


## Haengt die Anzeige an einen Kaempfer. Ab hier meldet sich der Kaempfer selbst,
## wenn sich etwas aendert - niemand muss ans Aktualisieren denken.
func show_combatant(combatant: Combatant) -> void:
	if _combatant == combatant:
		return
	if _combatant and _combatant.changed.is_connected(_refresh):
		_combatant.changed.disconnect(_refresh)

	_combatant = combatant
	_combatant.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	# show_combatant() kann aus game.gd._ready() kommen. Kinder sind zwar vor
	# ihrem Elternknoten bereit, aber darauf zu bauen ist eine unnoetige Falle.
	if _combatant == null or not is_node_ready():
		return

	%Bar.max_value = _combatant.max_health
	%Bar.value = _combatant.health
	%ValueLabel.text = "%d / %d" % [_combatant.health, _combatant.max_health]

	# Block bei 0 gar nicht zeigen, statt eine dauerhafte 0 im Blick zu haben -
	# das trainiert einen nur darauf, die Zeile zu ignorieren.
	%BlockLabel.text = "[center]%s %d[/center]" % [Icons.bb("block"), _combatant.block]
	%BlockLabel.visible = _combatant.block > 0
