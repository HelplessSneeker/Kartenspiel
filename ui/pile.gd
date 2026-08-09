class_name Pile
extends PanelContainer

## Ein Kartenstapel als Ort auf dem Tisch: Ziehstapel und Ablage.
##
## Vorher standen beide Zahlen als Text in der Kopfleiste. Das sagt, *wieviel*
## irgendwo liegt, aber nicht *wo* - und eine gespielte Karte verschwand
## ersatzlos, statt irgendwohin zu gehen. Der Stapel ist deshalb nicht nur
## huebscher, er ist der Zielpunkt, den die Kartenanimation braucht: hand.gd
## rechnet die Flugbahn aus der Position dieses Knotens aus.
##
## Kennt weder Deck noch Ablage - er zeigt eine Zahl und eine Beschriftung.
## Wer ihn womit fuellt, entscheidet game.gd.

## Beschriftung unter der Zahl. Steht im Inspector, damit dieselbe Szene fuer
## beide Stapel reicht - wie bei HealthView.
@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			%TitleLabel.text = title

var count: int = 0:
	set(value):
		count = value
		if is_node_ready():
			%CountLabel.text = str(count)


func _ready() -> void:
	%TitleLabel.text = title
	%CountLabel.text = str(count)
