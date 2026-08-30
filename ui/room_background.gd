class_name RoomBackground
extends Control

## Der Raum hinter allem: Verlauf, optionales Bild, Vignette.
##
## Stand zuerst als drei Knoten fest in game.tscn. Herausgezogen, als das
## Hauptmenue denselben Aufbau brauchte - also beim *zweiten* Nutzer und nicht
## beim ersten. Dieselbe Regel wie bei ui/icons.gd damals: eine Sache, die es
## einmal gibt, ist noch kein Bauteil.
##
## Die drei Ebenen von hinten nach vorn:
##
## - BaseRect: vertikaler Verlauf, oben heller. Immer da, auch ohne Bild - eine
##   Flaeche mit Verlauf hat schon Tiefe, eine einfarbige nicht.
## - SceneRect: das Bild. Fehlt es, bleibt der Verlauf allein stehen.
## - Vignette: radial nach aussen ins Dunkle. Liegt *ueber* dem Bild, nicht
##   darunter. Ein Foto konkurriert sonst mit dem, was darauf liegt, und die
##   Raender von Karten und Anzeigen verschwinden im Motiv.
##
## Verlauf und Vignette sind GradientTexture2D in der Szene, keine Dateien: kein
## Import, keine Lizenzfrage, und sie rechnen sich auf jede Aufloesung selbst
## aus statt zu skalieren.

## Das Bild des Schauplatzes. Leer heisst: nur Verlauf und Vignette.
@export var image: Texture2D:
	set(value):
		image = value
		# Dieselbe Falle wie in HealthView: der Setter laeuft beim Laden der
		# Szene, also vor _ready(), und dann gibt es %SceneRect noch nicht.
		if is_node_ready():
			_apply_image()

## Wie stark das Bild zurueckgenommen wird.
##
## Als Farbe und nicht als Zahl, damit man auch die Faerbung mitnehmen kann -
## ein leicht ins Blaue gezogener Hintergrund tritt weiter zurueck als ein bloss
## dunklerer. Multipliziert, also ist Weiss "unveraendert".
##
## Steht hier und nicht im Bild, weil es der Regler ist, an dem man dreht: die
## Unschaerfe ist in die Datei gebacken (der Hintergrund bewegt sich nie, ein
## Shader waere in jedem Frame umsonst bezahlt), das Abdunkeln nicht.
@export var dim := Color(0.5, 0.5, 0.55, 1):
	set(value):
		dim = value
		if is_node_ready():
			%SceneRect.modulate = dim


func _ready() -> void:
	%SceneRect.modulate = dim
	_apply_image()


func _apply_image() -> void:
	%SceneRect.texture = image
	%SceneRect.visible = image != null
