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
	%CostLabel.text = "Kosten: %d" % data.cost
	%TextLabel.text = data.description.format({
		"damage": data.damage,
		"block": data.block,
	})
	# Der Style haengt an `data`, und in _ready() gibt es die noch nicht -
	# deshalb hier und nicht dort.
	_apply_style()


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
