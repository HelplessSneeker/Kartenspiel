extends Resource
class_name CardData

## Was eine Karte ist: Name, Preis, Art - und eine Liste von Wirkungen.
##
## `damage` und `block` als eigene Felder sind weggefallen. Sie waren die
## Annahme, eine Karte koenne genau diese zwei Dinge tun; jede weitere Wirkung
## haette ein weiteres Feld gebraucht, das bei fast jeder Karte 0 ist. Die Liste
## kostet dafuer etwas mehr Umstand pro .tres, traegt aber alles, was noch kommt.

## Wofuer die Karte da ist. Faerbt den Rahmen, sonst (noch) ohne Regelwirkung.
##
## Hiess vorher `Category { AKTION, REAKTION }` und stammte aus dem reaktiven
## Stack-Modell: Karte legen, Gegner antwortet darauf. Gebaut ist ein Zugmodell
## nach Slay-the-Spire-Art, in dem es keine Reaktion gibt - das Feld beschrieb
## also eine Regel, die es nicht gibt, und "Reaktion" auf einer Karte war eine
## Zusage, die das Spiel nicht einhaelt.
enum Type { ANGRIFF, VERTEIDIGUNG, FERTIGKEIT }

@export var card_name: String = ""
@export var cost: int = 0
@export var type: Type = Type.ANGRIFF

## Wird der Reihe nach ausgefuehrt, wenn die Karte gespielt wird.
## Was eine Wirkung *tut*, steht nicht hier, sondern in game.gd - siehe dort.
@export var effects: Array[CardEffect] = []

@export_multiline var description: String = ""

## Das Bild auf der Karte. Darf leer bleiben - Karten ohne Bild zeigen einfach
## keins, statt ein Loch im Layout zu lassen (siehe card.gd).
##
## Bewusst ein Texture2D und kein Pfad-String: so haengt die Datei am
## Resource-System. Godot laedt sie mit der Karte, der Editor zeigt sie im
## Inspector, und ein Tippfehler faellt beim Import auf statt erst zur Laufzeit.
##
## Wie das Bild *zugeschnitten* wird, steht nicht hier, sondern im ArtRect in
## card.tscn - das ist Darstellung, keine Karteneigenschaft.
@export var art: Texture2D


## Die Zahlen fuer die Platzhalter im Kartentext.
##
## Der Text auf der Karte ist eine Schablone ("{icon_dmg} {damage} Schaden"),
## keine abgetippte Zahl - dadurch koennen Text und Regel nicht auseinander
## laufen. Frueher zog die Anzeige `damage` und `block` einfach aus zwei
## Feldern; jetzt gibt es die Felder nicht mehr, also muss jemand sagen, welche
## Zahl hinter `{damage}` steckt. Das gehoert hierher: nur die Karte weiss, was
## sie tut. Wie ein Schadenssymbol aussieht, geht sie dagegen nichts an - die
## `{icon_*}` legt die Anzeige dazu (card.gd).
##
## Bei mehreren Wirkungen derselben Art gewinnt die erste. Eine Karte, die
## zweimal auf verschiedene Weise Schaden macht, braucht ohnehin einen eigenen
## Text und keinen Platzhalter.
##
## Alle Schluessel sind immer da, notfalls mit 0: ein Platzhalter, den niemand
## fuellt, laesst format() sonst als rohes "{damage}" auf der Karte stehen.
func description_values() -> Dictionary:
	var values := {
		"damage": 0,
		"block": 0,
		"heal": 0,
		"draw": 0,
		"energy": 0,
		"self_damage": 0,
	}
	var filled := {}
	for effect in effects:
		if effect == null:
			continue
		var key := _value_key(effect.kind)
		if key == "" or filled.has(key):
			continue
		filled[key] = true
		values[key] = effect.amount
	return values


## Welcher Platzhalter im Kartentext welche Wirkung meint. Die Namen hier sind
## das, was in den .tres in geschweiften Klammern steht.
static func _value_key(kind: CardEffect.Kind) -> String:
	match kind:
		CardEffect.Kind.SCHADEN:
			return "damage"
		CardEffect.Kind.BLOCK:
			return "block"
		CardEffect.Kind.HEILEN:
			return "heal"
		CardEffect.Kind.ZIEHEN:
			return "draw"
		CardEffect.Kind.ENERGIE:
			return "energy"
		CardEffect.Kind.SELBSTSCHADEN:
			return "self_damage"
		_:
			return ""
