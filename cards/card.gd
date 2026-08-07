class_name CardView
extends PanelContainer

## Eine Karte auf der Hand.
##
## ACHTUNG, Kartenmasse haengen zusammen: die Labels in card.tscn haben
## custom_minimum_size.x = 110, die Karte selbst 130 - das ist 110 plus die
## zweimal 10 content_margin aus dem Theme. Diese Zahlen muessen zueinander
## passen, und die Label-Breite darf nicht "aufgeraeumt" werden.
##
## Grund: ein Label mit autowrap meldet als Mindestbreite fast nichts, weil es
## ja umbrechen kann. Godot rechnet die Mindesthoehe dann fuer genau diese
## winzige Breite aus, also fuer maximal viele Zeilen. Ohne feste Label-Breite
## meldet die Karte statt 190 rund 690 Pixel Hoehe - und hand.gd baut ihr
## Layout auf genau diesem Wert auf.
##
## CostLabel und TextLabel sind RichTextLabel, weil dort Icons per BBCode im
## Fliesstext stehen. Beide brauchen fit_content an und scroll_active aus -
## sonst melden sie ihre Inhaltshoehe nicht, sondern zeigen eine Scrollleiste.

## Wird gefeuert, wenn auf diese Karte geklickt wird.
## Die Karte selbst weiss nicht, was "spielen" bedeutet - das entscheidet game.gd.
signal clicked(card: CardView)

## Zu teuer - dauerhafter Zustand, haengt an der Energie.
const UNPLAYABLE_TINT := Color(0.55, 0.55, 0.55)

## Hand ruht - voruebergehender Zustand, haengt an der Maus.
const IDLE_TINT := Color(0.65, 0.65, 0.7)

## Rahmenfarbe je Kategorie - das Einzige am Kartenaussehen, das wirklich von
## den Kartendaten abhaengt. Hintergrund, Radius, Rahmenbreite und das Padding
## kommen aus dem Theme (Variation "Card") und stehen deshalb nicht mehr hier.
const BORDER_AKTION := Color("b4553c")
const BORDER_REAKTION := Color("4a7fb5")

## Icons, die in Kartentexten als Platzhalter auftauchen duerfen. Der Schluessel
## ist der Name, den die .tres benutzt: "{icon_dmg}" zieht ICON_PATHS["dmg"].
const ICON_PATHS := {
	"dmg": "res://assets/icons/damage.svg",
	"block": "res://assets/icons/block.svg",
	"energy": "res://assets/icons/energy.svg",
	"heal": "res://assets/icons/heal.svg",
}

## Die SVGs sind weiss, gefaerbt wird erst beim Rendern. Reinweiss ist neben dem
## gedaempften Fliesstext zu laut, deshalb je Bedeutung ein eigener Ton.
const ICON_TINTS := {
	"dmg": "#e08a6e",
	"block": "#7fb0e0",
	"energy": "#f0d070",
	"heal": "#8fd08f",
}

var data: CardData

## Beide Faerbungen sind unabhaengig voneinander und werden multipliziert:
## eine zu teure Karte in einer ruhenden Hand ist doppelt abgedunkelt.
var playable := true:
	set(value):
		playable = value
		_update_tint()

var dimmed := false:
	set(value):
		dimmed = value
		_update_tint()

var _tween: Tween


func setup(new_data: CardData) -> void:
	data = new_data
	%NameLabel.text = data.card_name
	%CostLabel.text = "%s %d" % [icon_bb("energy"), data.cost]
	# Zahlen und Icons wandern im selben format()-Aufruf in den Text. Eine .tres
	# schreibt also "{icon_dmg} {damage} Schaden" - Beschreibungen ohne
	# Icon-Platzhalter funktionieren unveraendert weiter.
	%TextLabel.text = data.description.format({
		"damage": data.damage,
		"block": data.block,
		"icon_dmg": icon_bb("dmg"),
		"icon_block": icon_bb("block"),
		"icon_energy": icon_bb("energy"),
		"icon_heal": icon_bb("heal"),
	})
	# Der Style haengt an `data`, und in _ready() gibt es die noch nicht -
	# deshalb hier und nicht dort.
	_apply_style()


## Baut das BBCode-Tag fuer ein Icon.
##
## height=1em bindet die Icongroesse an die Schriftgroesse ringsum, statt sie in
## Pixeln festzunageln - aendert sich die Schrift im Theme, wandern die Icons
## mit. color= toent die weisse Grafik ein; deshalb muessen die SVGs weiss sein
## und nicht schwarz, denn getoent wird multiplikativ und Schwarz bliebe schwarz.
static func icon_bb(icon_name: String) -> String:
	if not ICON_PATHS.has(icon_name):
		push_warning("Unbekanntes Icon: %s" % icon_name)
		return ""
	return "[img height=1em color=%s]%s[/img]" % [
		ICON_TINTS[icon_name], ICON_PATHS[icon_name],
	]


## Holt den StyleBox aus dem Theme und faerbt nur den Rahmen um.
##
## Der Theme-Type wird explizit mitgegeben, damit immer das Original aus dem
## Theme kommt und nicht der Override, den diese Methode selbst gesetzt hat -
## sonst faerbt jeder weitere Aufruf auf dem Ergebnis des vorigen.
##
## duplicate() ist Pflicht: StyleBoxes sind Resources und damit zwischen allen
## Karten geteilt. Ohne Kopie faerbt die zuletzt gebaute Karte rueckwirkend
## alle anderen mit um.
func _apply_style() -> void:
	var base := get_theme_stylebox("panel", "Card") as StyleBoxFlat
	if base == null:
		return
	var style: StyleBoxFlat = base.duplicate()
	style.border_color = _border_color()
	add_theme_stylebox_override("panel", style)


func _border_color() -> Color:
	if data == null:
		return BORDER_AKTION
	match data.category:
		CardData.Category.REAKTION:
			return BORDER_REAKTION
		_:
			return BORDER_AKTION


func snap_to(target_position: Vector2, target_scale: Vector2) -> void:
	_kill_tween()
	position = target_position
	scale = target_scale


func animate_to(target_position: Vector2, target_scale: Vector2, duration: float) -> void:
	# Ein laufender Tween muss weg, sonst zerren zwei um dieselbe Property
	# und die Karte zittert zwischen zwei Zielen.
	_kill_tween()
	_tween = create_tween().set_parallel()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target_position, duration)
	_tween.tween_property(self, "scale", target_scale, duration)


func _update_tint() -> void:
	var tint := Color.WHITE
	if not playable:
		tint *= UNPLAYABLE_TINT
	if dimmed:
		tint *= IDLE_TINT
	modulate = tint


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
