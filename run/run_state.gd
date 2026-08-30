extends Node

## Der laufende Durchlauf, als Autoload unter dem Namen `Run`.
##
## Das ist das Stueck Zustand, das einen Szenenwechsel ueberleben muss. Alles
## andere im Spiel darf mit seiner Szene sterben: eine Hand, ein Ziehstapel, ein
## Combatant gelten fuer genau einen Kampf. Deck, Leben und "der wievielte Kampf
## ist das" gelten fuer den Run - und zwischen zwei Kaempfen gibt es keine Szene,
## die sie halten koennte.
##
## Warum ueberhaupt Szenenwechsel und nicht alles in game.tscn? Weil ein Kampf
## sonst nie sauber endet: jeder Rest aus dem vorigen (laufende Tweens, Karten
## unterwegs, verbundene Signale) muesste von Hand zurueckgesetzt werden, und
## vergessen wuerde man genau einen davon. Eine neu geladene Szene faengt
## garantiert bei null an. Der Preis ist dieses Autoload.
##
## Kennt keine Szene und keine Anzeige - dieselbe Richtung wie Combatant und
## EnemyBrain. Es sagt, *was* der Stand ist; wer das anzeigt, fragt nach.

const CONFIG_PATH := "res://run/run_config.tres"

## Das Deck des Runs. Waechst spaeter zwischen den Kaempfen.
##
## Nicht zu verwechseln mit `deck` in game.gd: das ist der *Ziehstapel eines
## Kampfes* und schrumpft, waehrend man zieht. Der Kampf nimmt sich beim Start
## eine Kopie hiervon - deshalb kann er darin herumwuehlen, ohne den Run zu
## veraendern.
var deck: Array[CardData] = []

var health := 0
var max_health := 0

## Der wievielte Kampf gerade ansteht, ab 0.
var _index := 0

## Ob ueberhaupt schon ein Run gestartet wurde.
##
## Braucht es, weil "frisch hochgefahren" und "erster Kampf steht an" sonst
## gleich aussehen: _index ist in beiden Faellen 0. Ohne dieses Flag wuerde ein
## direkt geladenes game.tscn mit leerem Deck starten statt sich einen Run zu
## besorgen.
var _started := false

var _config: RunConfig


## Einmal beim Start laden statt per preload in der Konstanten - dieselbe
## Ueberlegung wie in den Audio-Autoloads: eine fehlende oder kaputte Datei
## faellt so als *eine* verstaendliche Fehlerzeile auf, statt das Skript am
## Parsen zu hindern und damit gleich das ganze Autoload umzubringen.
func _ready() -> void:
	_config = load(CONFIG_PATH) as RunConfig
	if _config == null:
		push_error("run_config.tres fehlt oder ist keine RunConfig: %s" % CONFIG_PATH)


## Setzt alles auf Anfang. Wird vom Hauptmenue gerufen und von jedem "Nochmal".
func start_new() -> void:
	if _config == null:
		return
	# duplicate() kopiert die Liste, nicht die Karten darin - beabsichtigt.
	# CardData ist im ganzen Projekt geteilte, zur Laufzeit unveraenderte Daten
	# (das Startdeck haelt Watschn fuenfmal als denselben Verweis). Kopiert wird
	# nur, damit ein Run das Startdeck nicht umschreibt.
	deck = _config.starting_deck.duplicate()
	max_health = maxi(_config.player_max_health, 1)
	health = max_health
	_index = 0
	_started = true


func is_active() -> bool:
	return _started and _config != null


## Der Gegner, der jetzt drankommt. Null, wenn der Run durch ist oder die
## Gegnerliste kuerzer ist als gedacht.
func current_enemy() -> EnemyData:
	if _config == null or _index < 0 or _index >= _config.enemies.size():
		return null
	return _config.enemies[_index]


## Kampf gewonnen: Leben uebernehmen und einen weiterruecken.
##
## Das Leben kommt von aussen herein, statt dass der Run es selbst mitrechnet.
## Waehrend eines Kampfes gehoert es dem Combatant - der weiss von Block,
## Heilung und Selbstschaden, und ein zweiter Zaehler daneben waere ein zweiter
## Ort, an dem dasselbe stehen muesste. Der Run holt es sich genau einmal ab,
## naemlich hier.
func win_fight(remaining_health: int) -> void:
	health = clampi(remaining_health, 0, max_health)
	_index += 1


## Alle Gegner gefallen.
func is_finished() -> bool:
	return _config != null and _index >= _config.enemies.size()


## Ab 1 gezaehlt - die Zahl geht in die Anzeige, und dort faengt man nicht bei 0 an.
func fight_number() -> int:
	return _index + 1


func fight_count() -> int:
	return _config.enemies.size() if _config else 0


func victory_title() -> String:
	return _config.victory_title if _config else "Geschafft"
