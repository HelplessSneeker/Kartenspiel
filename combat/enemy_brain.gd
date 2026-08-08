class_name EnemyBrain
extends RefCounted

## Entscheidet, was der Gegner als naechstes tut.
##
## Kennt weder Szene noch Anzeige noch Combatant - er liefert nur eine Aktion,
## ausgefuehrt wird sie in game.gd. Dieselbe Richtung wie ueberall sonst hier:
## Logik weiss nichts von dem, was sie anzeigt.
##
## Warum eine eigene Klasse fuer "geh eine Liste der Reihe nach durch"? Weil das
## Design-Doc den Gegner als *austauschbaren Controller* fuehrt. Solange die Naht
## existiert, ist "feste Reihenfolge" -> "waehlt nach Spielerleben" ein Tausch in
## einer Zeile. Wuerde der Index in game.gd liegen, waere es ein Umbau.

## Die Aktion, die der Gegner im naechsten Gegnerzug ausfuehrt.
##
## Sie steht fest, *bevor* der Spieler seinen Zug macht - und genau das ist der
## Punkt des ganzen Systems: der Spieler soll wissen, ob gleich 12 Schaden
## kommen, und danach entscheiden koennen, ob er blockt oder zuschlaegt. Ohne
## diese Vorschau waere Block reines Raten.
var intent: EnemyAction = null

var _pattern: Array[EnemyAction] = []
var _index := 0


func _init(pattern: Array[EnemyAction]) -> void:
	_pattern = pattern


## Legt die naechste Aktion fest und rueckt im Muster weiter.
##
## Leeres Muster -> intent bleibt null, der Gegner tut nichts. Das Spiel laeuft
## dann trotzdem, statt beim Laden auszusteigen: einen halb gefuellten Inspector
## soll man ausprobieren koennen.
func plan() -> void:
	if _pattern.is_empty():
		intent = null
		return
	intent = _pattern[_index]
	_index = (_index + 1) % _pattern.size()
