class_name HealthView
extends VBoxContainer

## Zeigt einen Combatant an: Name, Lebensbalken, Zahl, Block.
##
## Die Knoten stehen in health_view.tscn, das Aussehen im Theme. Vorher baute
## dieses Skript seine Kinder selbst und trug seine Farben als Konstanten - das
## war richtig, solange es kein Theme gab. Jetzt gibt es eins, und Farben an
## zwei Orten zu pflegen ist genau der Zustand, den Session 1 aufgeraeumt hat.
##
## KEIN PanelContainer mehr (30.08.2026). Solange der Hintergrund eine flache
## Farbe war, gab der Rahmen der Anzeige ueberhaupt erst eine Form. Seit hinter
## dem Kampf ein Raum liegt, tut er das Gegenteil: zwei umrandete Kaesten auf
## einem Foto lesen sich wie aufgeklebte Karteikarten, nicht wie zwei Figuren,
## die einander gegenueberstehen. Jetzt steht die Figur frei, und nur das
## Portraet hat noch einen Rahmen - das ist der Unterschied zwischen "eine
## Person im Raum" und "ein Kasten mit einer Person drin".
##
## Der Preis dafuer: die Schrift liegt jetzt direkt auf dem Bild. Deshalb haben
## HealthTitle, HealthValue und HealthBlock im Theme eine Kontur bekommen. Ohne
## sie verschwindet ein heller Name auf einer hellen Wand.
##
## Die Zahl liegt seit 03.09.2026 *auf* dem Balken statt darunter (Befund aus
## bfns Screenshots: der Balken war ein nackter roter Block und das Lauteste am
## Bildschirm). Ein Balken mit Zahl darin liest sich als Anzeige, ein Balken mit
## Zahl darunter als zwei Dinge. `%ValueLabel` wandert dabei nur im Baum - der
## eindeutige Name loest weiterhin auf, deshalb aendert sich hier keine Zeile.
##
## Ein *Rahmen* um den Balken geht nicht, obwohl er alles andere im Theme hat:
## ProgressBar zeichnet die Fuellung ueber die volle Breite des Knotens und
## nicht innerhalb der Raender des Hintergrunds (progress_bar.cpp nachgesehen).
## Ein Rahmen waere bei vollem Leben komplett verdeckt und bei halbem nur rechts
## zu sehen. Stattdessen ist die Fuellung entsaettigt und der Hintergrund
## dunkler - der Balken ordnet sich damit ein, ohne einen Rahmen zu brauchen.
##
## Seit dem Juice-Durchgang hat die Anzeige zwei Aufgaben, die man nicht
## verwechseln sollte: den *Zustand* zeigen (_refresh, haengt an `changed`) und
## auf *Ereignisse* reagieren (Zahl, Ruck, Aufleuchten - haengt an damaged,
## healed, blocked). Der Zustand muss immer stimmen, auch wenn keine Animation
## laeuft. Deshalb ist alles Bewegte hier reine Zutat: nimmt man es weg,
## funktioniert die Anzeige unveraendert.

const FLOATING_NUMBER := preload("res://ui/floating_number.tscn")

## Dieselben Toene wie die Icons (Icons.TINTS): eine rote Zahl gehoert zum roten
## Schadenssymbol. Sie stehen hier trotzdem noch einmal als Color statt als
## Verweis, weil Icons.TINTS Hex-Strings fuer BBCode haelt - der Umweg ueber
## Color(Icons.TINTS["dmg"]) waere kuerzer, aber er wuerde die Icon-Liste zu
## etwas machen, das auch Nicht-Icons faerbt.
const HIT_COLOR := Color("e08a6e")
const BLOCK_COLOR := Color("7fb0e0")
const HEAL_COLOR := Color("8fd08f")

## Kurzer Stoss auf die ganze Anzeige beim Treffer.
##
## Warum Skalierung und kein Ruetteln? Ruetteln waere `position` - und die
## gehoert dem HBoxContainer in game.tscn, der sie beim naechsten Sortieren
## zurueckschreibt. Sortiert wird waehrend des Kampfes staendig, weil das
## Blocklabel je nach Blockwert erscheint und verschwindet. `scale` fasst kein
## Container an, also ist es der einzige Weg, der nicht zufaellig funktioniert.
const PUNCH_SCALE := 1.05
const PUNCH_UP := 0.07
const PUNCH_DOWN := 0.16

## Das Portraet leuchtet kurz rot. Werte ueber 1 sind Absicht: modulate
## multipliziert, und ein Faktor unter 1 wuerde das Bild nur abdunkeln.
const FLASH_COLOR := Color(1.7, 0.75, 0.7)
const FLASH_TIME := 0.28

## Der Balken laeuft nach, statt zu springen. Kurz genug, dass er beim naechsten
## Treffer schon steht - ein Balken, der noch von der letzten Karte laeuft,
## waehrend die naechste trifft, zeigt nie den Stand, der gerade gilt.
const BAR_TIME := 0.35

## Seitlicher Versatz, wenn ein Treffer zwei Zahlen erzeugt.
const SPLIT_DRIFT := 26.0

## Beschriftung ueber dem Balken. Steht im Inspector, damit dasselbe Skript und
## dieselbe Szene fuer Spieler und Gegner reichen.
@export var title: String = "":
	set(value):
		title = value
		# Der Setter laeuft beim Laden der Szene, also vor _ready(). Zu dem
		# Zeitpunkt gibt es %TitleLabel noch nicht - _ready() holt es nach.
		if is_node_ready():
			%TitleLabel.text = title

## Das Bild ueber der Beschriftung. Wie `title` im Inspector gesetzt, aus dem
## gleichen Grund: eine Szene, zwei Kaempfer, kein zweites Skript.
##
## Ohne Bild bleibt der ganze Rahmen unsichtbar und die Anzeige sieht aus wie
## vorher - eine HealthView ohne Portraet ist also weiterhin gueltig.
@export var portrait: Texture2D:
	set(value):
		portrait = value
		# Gleiche Falle wie oben: der Setter laeuft vor _ready().
		if is_node_ready():
			_apply_portrait()

var _combatant: Combatant

var _punch_tween: Tween
var _flash_tween: Tween
var _bar_tween: Tween

## Ob der Balken schon einmal einen Wert gezeigt hat.
##
## Beim allerersten Mal wird gesetzt statt getweent: sonst liefe der Balken beim
## Kampfstart von 0 auf volles Leben hoch, und das saehe aus wie Heilung, bevor
## irgendwas passiert ist.
var _bar_shown := false


func _ready() -> void:
	%TitleLabel.text = title
	_apply_portrait()
	_refresh()


## Versteckt wird der *Rahmen*, nicht das Bild darin: ohne Portraet soll auch
## kein leerer Rahmen mit Schatten dastehen.
func _apply_portrait() -> void:
	%PortraitRect.texture = portrait
	%PortraitFrame.visible = portrait != null


## Haengt die Anzeige an einen Kaempfer. Ab hier meldet sich der Kaempfer selbst,
## wenn sich etwas aendert - niemand muss ans Aktualisieren denken.
func show_combatant(combatant: Combatant) -> void:
	if _combatant == combatant:
		return
	# Die vier Signale werden immer gemeinsam verbunden und gemeinsam geloest -
	# deshalb genuegt hier eine Abfrage auf _combatant statt vier auf
	# is_connected(). Wer das aufbricht und nur eines verbindet, holt sich die
	# Einzelpruefungen zurueck.
	if _combatant:
		_combatant.changed.disconnect(_refresh)
		_combatant.damaged.disconnect(_on_damaged)
		_combatant.healed.disconnect(_on_healed)
		_combatant.blocked.disconnect(_on_blocked)

	_combatant = combatant
	_combatant.changed.connect(_refresh)
	_combatant.damaged.connect(_on_damaged)
	_combatant.healed.connect(_on_healed)
	_combatant.blocked.connect(_on_blocked)
	_refresh()


func _refresh() -> void:
	# show_combatant() kann aus game.gd._ready() kommen. Kinder sind zwar vor
	# ihrem Elternknoten bereit, aber darauf zu bauen ist eine unnoetige Falle.
	if _combatant == null or not is_node_ready():
		return

	%Bar.max_value = _combatant.max_health
	_move_bar_to(_combatant.health)
	# Die Zahl springt weiterhin sofort, waehrend der Balken nachlaeuft. Das ist
	# Absicht: die Zahl ist die Auskunft ("wie viel hat er noch"), der Balken ist
	# das Gefuehl. Eine mitlaufende Zahl waere waehrend der Bewegung schlicht
	# falsch, und man kann sie nicht ablesen, solange sie zappelt.
	%ValueLabel.text = "%d / %d" % [_combatant.health, _combatant.max_health]

	# Block bei 0 gar nicht zeigen, statt eine dauerhafte 0 im Blick zu haben -
	# das trainiert einen nur darauf, die Zeile zu ignorieren.
	%BlockLabel.text = "[center]%s %d[/center]" % [Icons.bb("block"), _combatant.block]
	%BlockLabel.visible = _combatant.block > 0


# --- Rueckmeldung -------------------------------------------------------------

## Ein Treffer. Zwei Zahlen, wenn der Block einen Teil geschluckt hat: der
## Spieler soll sehen, dass sein Bierchen etwas getan hat, und nicht nur den
## Rest, der durchgekommen ist.
func _on_damaged(health_lost: int, block_lost: int) -> void:
	var split := health_lost > 0 and block_lost > 0
	if block_lost > 0:
		_pop("-%d" % block_lost, BLOCK_COLOR, -SPLIT_DRIFT if split else 0.0)
	if health_lost > 0:
		_pop("-%d" % health_lost, HIT_COLOR, SPLIT_DRIFT if split else 0.0)

	# Der Stoss kommt immer, auch wenn der Block alles gehalten hat: etwas ist
	# angekommen, das soll man spueren. Rot aufleuchten nur, wenn es ans Leben
	# ging - sonst waere am Bild nicht zu unterscheiden, ob der Block gehalten hat.
	_punch()
	if health_lost > 0:
		_flash()


func _on_healed(amount: int) -> void:
	_pop("+%d" % amount, HEAL_COLOR, 0.0)


func _on_blocked(amount: int) -> void:
	_pop("+%d" % amount, BLOCK_COLOR, 0.0)


func _pop(value_text: String, color: Color, drift: float) -> void:
	var number: FloatingNumber = FLOATING_NUMBER.instantiate()
	# Erst in den Baum, dann starten: create_tween() braucht einen Knoten, der
	# drin haengt.
	add_child(number)
	number.play(value_text, color, _pop_origin(), drift)


## Wo die Zahl losfliegt: ueber dem Portraet, leicht oberhalb der Mitte.
##
## Ohne Portraet die Mitte der ganzen Anzeige - eine HealthView ohne Bild ist
## weiterhin gueltig, und die Zahl soll dann nicht im Nichts starten.
func _pop_origin() -> Vector2:
	var anchor: Control = %PortraitFrame if %PortraitFrame.visible else self
	return anchor.global_position + Vector2(anchor.size.x * 0.5, anchor.size.y * 0.3)


func _punch() -> void:
	_kill(_punch_tween)
	# Um die Mitte wachsen, nicht um die linke obere Ecke.
	pivot_offset = size * 0.5
	_punch_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_punch_tween.tween_property(self, "scale", Vector2.ONE * PUNCH_SCALE, PUNCH_UP).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "scale", Vector2.ONE, PUNCH_DOWN).set_ease(Tween.EASE_IN)


func _flash() -> void:
	if not %PortraitFrame.visible:
		return
	_kill(_flash_tween)
	%PortraitRect.modulate = FLASH_COLOR
	_flash_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(%PortraitRect, "modulate", Color.WHITE, FLASH_TIME)


func _move_bar_to(value: float) -> void:
	_kill(_bar_tween)
	if not _bar_shown:
		_bar_shown = true
		%Bar.value = value
		return
	_bar_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bar_tween.tween_property(%Bar, "value", value, BAR_TIME)


## Ein laufender Tween muss weg, bevor ein neuer dieselbe Property anfasst -
## sonst zerren zwei um denselben Wert und das Ergebnis haengt am Zufall.
## Dieselbe Regel wie in CardView, nur fuer mehrere Tweens.
func _kill(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()
