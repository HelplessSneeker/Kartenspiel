class_name CardView
extends PanelContainer

## Eine Karte auf der Hand.
##
## ACHTUNG, Kartenmasse haengen zusammen: die Labels und das ArtRect in
## card.tscn haben custom_minimum_size.x = 110, die Karte selbst 130 - das ist
## 110 plus die zweimal 10 content_margin aus dem Theme. Diese Zahlen muessen
## zueinander passen, und die Label-Breite darf nicht "aufgeraeumt" werden.
##
## Grund: ein Label mit autowrap meldet als Mindestbreite fast nichts, weil es
## ja umbrechen kann. Godot rechnet die Mindesthoehe dann fuer genau diese
## winzige Breite aus, also fuer maximal viele Zeilen. Ohne feste Label-Breite
## meldet die Karte statt 250 rund 690 Pixel Hoehe - und hand.gd baut ihr
## Layout auf genau diesem Wert auf.
##
## Die Kartenhoehe (250) ist dagegen unkritisch: hand.gd fragt sie ueber
## get_combined_minimum_size() ab, statt sie zu kennen. Sie war 190, bevor das
## Bild dazukam - 80 Pixel Bild plus die zusaetzliche VBox-Separation von 6
## haetten sonst den Text aus der Karte geschoben.
##
## Das ArtRect steht auf expand_mode = EXPAND_IGNORE_SIZE und stretch_mode =
## STRETCH_KEEP_ASPECT_COVERED. IGNORE_SIZE, damit ein 220 Pixel breites Foto
## nicht 220 Pixel Kartenbreite verlangt; COVERED, damit es den Rahmen fuellt
## statt Balken zu lassen. COVERED schneidet dafuer ueber den Rahmen hinaus -
## deshalb clip_contents.
##
## Die Bilder in assets/art/ sind bereits auf 220x160 zugeschnitten, also genau
## das doppelte des Rahmens. Godot schneidet an ihnen deshalb nichts weg, es
## skaliert nur auf die Haelfte - das Doppelte ist Reserve fuer Bildschirme mit
## hoher Pixeldichte. COVERED ist trotzdem richtig gesetzt: es faengt den Fall
## ab, dass jemand ein Bild mit anderem Seitenverhaeltnis nachlegt. Dann wird
## dessen Mitte gezeigt - einen Zuschnitt pro Karte gibt es nicht, der gehoert
## ins Bild selbst.
##
## CostLabel und TextLabel sind RichTextLabel, weil dort Icons per BBCode im
## Fliesstext stehen. Drei Properties sind dabei Pflicht:
##
## - fit_content an und scroll_active aus, sonst meldet das Label seine
##   Inhaltshoehe nicht, sondern zeigt eine Scrollleiste.
## - mouse_filter auf IGNORE. Label steht von Haus aus auf IGNORE,
##   RichTextLabel dagegen auf STOP, weil es Links und Textauswahl kann. Auf
##   STOP schluckt es die Maus, und die Karte darunter bekommt weder Hover noch
##   Klick - die Karte ist dann nur noch an ihren Raendern bedienbar.

## Wird gefeuert, wenn auf diese Karte geklickt wird.
## Die Karte selbst weiss nicht, was "spielen" bedeutet - das entscheidet game.gd.
signal clicked(card: CardView)

## Zu teuer - dauerhafter Zustand, haengt an der Energie.
const UNPLAYABLE_TINT := Color(0.55, 0.55, 0.55)

## Hand ruht - voruebergehender Zustand, haengt an der Maus.
const IDLE_TINT := Color(0.65, 0.65, 0.7)

## Rahmenfarbe je Kartenart - das Einzige am Kartenaussehen, das wirklich von
## den Kartendaten abhaengt. Hintergrund, Radius, Rahmenbreite und das Padding
## kommen aus dem Theme (Variation "Card") und stehen deshalb nicht mehr hier.
##
## Die Toene sind bewusst dieselben wie die der Icons (siehe Icons.TINTS): eine
## Karte mit rotem Rahmen zeigt ein rotes Schadenssymbol. Fertigkeit hat kein
## eigenes Icon und bekommt deshalb einen Ton, den sonst nichts benutzt.
const BORDER_ANGRIFF := Color("b4553c")
const BORDER_VERTEIDIGUNG := Color("4a7fb5")
const BORDER_FERTIGKEIT := Color("8a7ab5")

## Statuskarten sind absichtlich das einzige Grau in der Hand: sie sind der
## einzige Kartentyp, der nichts anbietet, und sollen zwischen den vier bunten
## auch so aussehen. Zusaetzlich haengt an ihnen dauerhaft UNPLAYABLE_TINT -
## eine Statuskarte ist nie spielbar, also nie hell.
const BORDER_STATUS := Color("5a5a62")


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
	# Statuskarten kosten nichts und koennen nichts kosten - eine "0" davor waere
	# ein Preis, der so aussieht, als koennte man dafuer etwas bekommen.
	%CostLabel.text = "" if not data.is_playable() else "%s %d" % [Icons.bb("energy"), data.cost]
	# Zahlen und Icons wandern im selben format()-Aufruf in den Text. Eine .tres
	# schreibt also "{icon_dmg} {damage} Schaden" - Beschreibungen ohne
	# Icon-Platzhalter funktionieren unveraendert weiter.
	%TextLabel.text = Icons.fill(data.description, data.description_values())
	# Eine Karte ohne Bild soll keinen leeren 80-Pixel-Block zeigen. visible aus
	# nimmt den Node aus der VBox-Rechnung heraus, die Karte wird entsprechend
	# kuerzer - und weil hand.gd die Hoehe abfragt statt sie zu kennen, darf sie
	# das auch. Karten mit und ohne Bild sind dann allerdings verschieden hoch.
	%ArtRect.texture = data.art
	%ArtRect.visible = data.art != null
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
		return BORDER_ANGRIFF
	match data.type:
		CardData.Type.VERTEIDIGUNG:
			return BORDER_VERTEIDIGUNG
		CardData.Type.FERTIGKEIT:
			return BORDER_FERTIGKEIT
		CardData.Type.STATUS:
			return BORDER_STATUS
		_:
			return BORDER_ANGRIFF


func snap_to(target_position: Vector2, target_scale: Vector2) -> void:
	_kill_tween()
	position = target_position
	scale = target_scale


## `delay` staffelt das Austeilen: fuenf Karten, die gleichzeitig losfliegen,
## sind ein Sprung, fuenf im Abstand von Sekundenbruchteilen sind fuenf Karten.
func animate_to(target_position: Vector2, target_scale: Vector2, duration: float, delay: float = 0.0) -> void:
	# Ein laufender Tween muss weg, sonst zerren zwei um dieselbe Property
	# und die Karte zittert zwischen zwei Zielen.
	_kill_tween()
	_tween = create_tween().set_parallel()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target_position, duration).set_delay(delay)
	_tween.tween_property(self, "scale", target_scale, duration).set_delay(delay)


## Letzte Reise: zur Ablage schrumpfen, ausblenden, sich selbst wegraeumen.
##
## Die Karte raeumt sich am Ende selbst weg, statt dass der Aufrufer einen Timer
## stellt und hofft. Wer die Dauer kennt, soll auch das Aufraeumen besitzen.
##
## Dass hier `modulate` angefasst wird, geht nur gut, weil eine ausfliegende
## Karte vorher aus der Hand entlassen wurde: `playable` und `dimmed` schreiben
## dieselbe Property, und ein Hover-Wechsel wuerde das Ausblenden sonst
## zurueckdrehen.
func fly_out(target_position: Vector2, target_scale: Vector2, duration: float) -> void:
	_kill_tween()
	_tween = create_tween().set_parallel()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", target_position, duration)
	_tween.tween_property(self, "scale", target_scale, duration)
	_tween.tween_property(self, "modulate:a", 0.0, duration)
	# chain() haengt hinter *alle* parallelen Tweener, nicht neben sie.
	_tween.chain().tween_callback(queue_free)


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
