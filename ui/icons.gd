class_name Icons
extends RefCounted

## Symbole, die in Texten per BBCode auftauchen. Reine Namensliste, wird nie
## instanziiert - alles daran ist static.
##
## Lag zuerst in card.gd. Solange nur die Karten Icons brauchten, war das der
## richtige Ort; mit der Lebensanzeige gibt es einen zweiten Nutzer, und ab da
## gehoert es an eine Stelle, die keinem von beiden gehoert.

const PATHS := {
	"dmg": "res://assets/icons/damage.svg",
	"block": "res://assets/icons/block.svg",
	"energy": "res://assets/icons/energy.svg",
	"heal": "res://assets/icons/heal.svg",
}

## Die SVGs sind weiss, gefaerbt wird erst beim Rendern. Reinweiss ist neben
## gedaempftem Fliesstext zu laut, deshalb je Bedeutung ein eigener Ton.
const TINTS := {
	"dmg": "#e08a6e",
	"block": "#7fb0e0",
	"energy": "#f0d070",
	"heal": "#8fd08f",
}


## Baut das BBCode-Tag fuer ein Icon.
##
## height=1em bindet die Icongroesse an die Schriftgroesse ringsum, statt sie in
## Pixeln festzunageln - aendert sich die Schrift im Theme, wandern die Icons
## mit. color= toent die weisse Grafik ein; deshalb muessen die SVGs weiss sein
## und nicht schwarz, denn getoent wird multiplikativ und Schwarz bliebe schwarz.
static func bb(icon_name: String) -> String:
	if not PATHS.has(icon_name):
		push_warning("Unbekanntes Icon: %s" % icon_name)
		return ""
	return "[img height=1em color=%s]%s[/img]" % [TINTS[icon_name], PATHS[icon_name]]


## Fuellt eine Textschablone: Zahlen vom Aufrufer, Symbole von hier.
##
## Die Trennung ist der Punkt. Was eine Karte tut, weiss nur sie selbst - wie
## ein Schadenssymbol aussieht, ist Darstellung und hat in einer .tres nichts
## verloren. Beides trifft sich erst in diesem einen Dictionary.
##
## Stand vorher als `_text_values()` in card.gd. Mit dem Gegner-Intent gab es
## einen zweiten Aufrufer, der dieselben vier Zeilen gebraucht haette - und ein
## Icon, das in card.gd nachgetragen wird, waere im Intent stumm geblieben.
##
## Die Liste der `{icon_*}` wird aus PATHS erzeugt statt abgetippt: ein neues
## Icon eintragen genuegt, es steht sofort in jedem Text zur Verfuegung.
##
## `values` wird kopiert, nicht ergaenzt - der Aufrufer soll sein Dictionary
## unveraendert wiederbekommen.
static func fill(template: String, values: Dictionary) -> String:
	var merged := values.duplicate()
	for icon_name in PATHS:
		merged["icon_%s" % icon_name] = bb(icon_name)
	return template.format(merged)
