class_name EnergyOrb
extends Control

## Die Energiekugel: ein Ring aus so vielen Abschnitten, wie es Energie gibt.
## Ausgegebene Abschnitte werden grau, uebrige bleiben gold.
##
## Warum gezeichnet und nicht aus StyleBoxen gebaut? Weil ein StyleBox ein
## Rechteck mit Eckenradius ist - er kann rund aussehen, aber nicht *teilweise*
## rund sein. "Drei von vier Vierteln" ist keine Form, die man mit Rahmenbreiten
## beschreibt. draw_arc() beschreibt sie in einer Zeile.
##
## Der Vorteil gegenueber einer Zahl allein: man muss nicht lesen. Wie viel man
## noch hat, ist eine Menge und keine Ziffer - und waehrend man ueber die Hand
## faehrt, will man den Blick nicht auf eine Stelle ziehen, an der etwas steht,
## das man erst entziffert.

## Wie breit der Ring ist. Nach innen gezeichnet, siehe _draw().
const RING_WIDTH := 7.0

## Luecke zwischen zwei Abschnitten, in Radiant. Ohne sie ist der Ring bei
## voller Energie ein durchgehender Kreis, und dann sieht man nicht, in wie
## viele Stuecke er zerfaellt, bevor das erste fehlt.
const GAP := 0.12

const FILLED := Color("d0ac73")

## Der ausgegebene Rest bleibt sichtbar, statt zu verschwinden. Eine Luecke
## saehe nach Beschaedigung aus; ein grauer Abschnitt sagt "hier war etwas".
const SPENT := Color("3d3428")

const BG := Color(0.0862745, 0.0705882, 0.054902, 0.92)

## Wie viele Abschnitte der Ring hat.
@export var maximum := 4:
	set(value):
		maximum = maxi(value, 0)
		queue_redraw()

## Wie viele davon noch gefuellt sind.
@export var filled := 4:
	set(value):
		filled = clampi(value, 0, maximum)
		queue_redraw()


func _draw() -> void:
	var middle := size * 0.5
	# Der Radius liegt auf der *Mitte* der Ringlinie - draw_arc() zeichnet die
	# Breite je zur Haelfte nach innen und aussen. Ohne das halbe RING_WIDTH
	# Abzug ragt der Ring ueber den Knoten hinaus und wird an den Raendern
	# abgeschnitten, sobald jemand clip_contents setzt.
	var radius := minf(size.x, size.y) * 0.5 - RING_WIDTH * 0.5
	if radius <= 0.0:
		return

	# Die Fuellung endet an der Innenkante des Rings, sonst schimmert sie unter
	# den grauen Abschnitten durch und macht sie heller als beabsichtigt.
	draw_circle(middle, radius - RING_WIDTH * 0.5, BG)

	if maximum <= 0:
		return

	var step := TAU / maximum
	for i in maximum:
		# Bei -PI/2 ist zwoelf Uhr. Von dort im Uhrzeigersinn, weil "verbraucht
		# wird von oben weg" der Leserichtung einer Uhr folgt.
		var from := -PI * 0.5 + i * step + GAP * 0.5
		var to := from + step - GAP
		# 24 Stuetzpunkte je Abschnitt: bei einem Ring von 72 Pixeln ist der
		# Unterschied zu 64 nicht mehr zu sehen, der zu 8 sehr wohl.
		draw_arc(middle, radius, from, to, 24, FILLED if i < filled else SPENT, RING_WIDTH, true)
