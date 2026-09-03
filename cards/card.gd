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
## Die Kartenhoehe (230) ist dagegen unkritisch: hand.gd fragt sie ueber
## get_combined_minimum_size() ab, statt sie zu kennen.
##
## Die Zahl war zweimal falsch. Erst 190, bevor das Bild dazukam. Dann 250 -
## und das war zu viel: Name, Plakette, ein 80 Pixel hohes Bild und zwei Zeilen
## Text ergeben rund 200, also stand das untere Fuenftel jeder Karte leer. Auf
## einem Screenshot (03.09.2026) war das der Grund, warum die Karten unfertig
## wirkten, deutlicher als jede Farbe.
##
## Jetzt 230 bei 110 Pixel Bildhoehe: die Karte ist voll, und das Bild ist rund
## 40% groesser - bei einem Foto von 110x80 erkennt man nicht, was drauf ist,
## und der Witz der Karte lebt vom Motiv.
##
## Warum nicht noch groesser: die Bilder sind querformatig (220x160), und
## STRETCH_KEEP_ASPECT_COVERED schneidet den Ueberschuss seitlich weg. Bei 110
## Bildhoehe bleiben rund drei Viertel der Breite stehen, bei 130 nur noch gut
## die Haelfte - dann verliert "Watschen Bam" die aeusseren Haende, und die
## sind der Inhalt. An einem Mockup mit den echten Bildern verglichen.
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
## Die Kosten sitzen seit 30.08.2026 in einer Plakette (CostBadge, Theme-
## Variation "CostBadge") statt als nackte Textzeile im Fluss. Beim Ueberfliegen
## der Hand sucht man zwei Dinge: was kostet es und was tut es - der Preis muss
## also als eigenes Ding lesbar sein und nicht als erste Zeile Text.
##
## Warum kein Kreis in der Ecke, wie in den meisten Kartenspielen? Weil er das
## Breitenverhaeltnis oben brechen wuerde. Neben den Namen gestellt, muesste
## NameLabel schmaler werden (110 minus Plakette minus Abstand) - und damit
## bricht jeder laengere Kartenname frueher um. Darueber gelegt, kollidiert er
## mit genau diesen umgebrochenen Namen. Beides sind Aenderungen, deren Ergebnis
## man *sehen* muss, und genau das kann ich nicht. Die Plakette im Fluss braucht
## dagegen keine einzige Breitenzahl: size_flags_horizontal = SHRINK_BEGIN, sie
## ist so breit wie ihr Inhalt und sonst nichts.
##
## CostLabel steht auf autowrap_mode = OFF. Das ist hier kein Detail: die
## Plakette zieht ihre Breite aus dem Label, und ein Label mit Umbruch meldet
## als Mindestbreite fast nichts - dieselbe Falle wie oben beim Namen, nur
## andersherum. Ohne Umbruch meldet es die volle Zeilenbreite, und die Plakette
## legt sich genau darum.
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

## Was auf der Plakette steht.
##
## Eigene Property statt eines direkten Blicks in `data.cost`, weil eine Karte
## im Kampf teurer werden kann (siehe cost_growth in card_data.gd) - dann stimmt
## die Zahl in der Resource nicht mehr mit der ueberein, die tatsaechlich
## verlangt wird. Was etwas kostet, weiss der Kampf; die Karte zeigt an, was man
## ihr sagt.
##
## setup() setzt den Grundpreis ein, damit eine Karte auch ohne Kampf drumherum
## etwas Sinnvolles zeigt - die Hand schreibt den echten Preis danach drueber.
var cost: int = 0:
	set(value):
		cost = value
		_update_cost()
		# Auch der Text: bei einer X-Karte ist der Preis zugleich der Multiplikator
		# ("5 Schaden ×3"), die Beschreibung veraltet also mit jeder Preisaenderung.
		_update_text()

## Ob diese Ansicht ausserhalb eines Kampfes steht - Belohnungsauswahl, spaeter
## eine Deckansicht. Dann sind `cost` und alles, was daran haengt, keine echten
## Zahlen, sondern der Grundpreis aus der Resource.
##
## Betrifft in der Praxis nur X-Karten, und dort ist es der ganze Unterschied:
## ohne Kampf gibt es keine Energie, die man ausgeben koennte, also steht auf der
## Karte X - "so viel du hast". Liegt sie in der Hand, steht die Zahl da, die es
## gerade wirklich ist. Die Vorschau zeigt die Regel, die Hand den Zug.
##
## Voreinstellung true, weil das die sichere Antwort ist: wer eine Karte baut,
## ohne ihr einen Preis zu sagen, kennt die Energie nicht. hand.gd setzt es auf
## false, sobald ein Kampf dahintersteht (siehe cost_lookup dort).
var preview := true:
	set(value):
		preview = value
		_update_cost()
		_update_text()

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
	# Ueber die Property, damit die Plakette nur an einer Stelle beschrieben wird
	# (siehe _update_cost). Der Grundpreis ist hier nur der Startwert - die Hand
	# ersetzt ihn gleich durch den, der im Kampf wirklich gilt.
	cost = data.cost
	# Schreibt auch den Text - der Setter oben hat das bereits getan, hier steht
	# es fuer den Fall, dass jemand setup() ohne anschliessende Preisvergabe ruft.
	_update_text()
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


## Wie gross die Karte im Moment des Einschlags ist.
##
## Ueber 1, damit die Bewegung nach *vorn* liest und nicht nur zur Seite. Der
## Pivot sitzt auf Unterkante-Mitte, die Karte waechst also nach oben - genau
## dorthin, wo bei der HealthView gleich die Zahl aufsteigt.
const STRIKE_SCALE := 1.15


## Der Weg zum Ziel: die Karte faehrt auf den Gegner (oder den Spieler) zu.
##
## Zwischenschritt vor fly_out(). Vorher ging eine gespielte Karte direkt zur
## Ablage, waehrend der Schaden gleichzeitig irgendwo anders auf dem Bildschirm
## abgezogen wurde - zwei Ereignisse, die zusammengehoeren, an zwei Orten. Jetzt
## ist die Karte dort, wo es wehtut, wenn es wehtut.
##
## EASE_IN, im Gegensatz zu jeder anderen Bewegung in dieser Datei: eine
## Bewegung, die beschleunigt, liest sich als Zuschlagen. EASE_OUT waere ein
## Gleiten - richtig fuer Karten, die sich sortieren, falsch fuer eine Watschn.
func strike(target_position: Vector2, duration: float) -> void:
	_kill_tween()
	_tween = create_tween().set_parallel()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "position", target_position, duration)
	_tween.tween_property(self, "scale", Vector2.ONE * STRIKE_SCALE, duration)


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


## Schreibt die Kostenplakette.
##
## Statuskarten kosten nichts und koennen nichts kosten - eine "0" davor waere
## ein Preis, der so aussieht, als bekaeme man dafuer etwas. Frueher stand dort
## ein leerer Text; jetzt verschwindet die ganze Plakette, sonst saesse auf
## einer Statuskarte ein leerer Ring.
##
## Der data-Check faengt den Setter ab, der vor setup() feuern kann: `cost` hat
## einen Startwert, und wer die Karte instanziiert, ohne sie zu befuellen, soll
## damit keinen Fehler ausloesen.
func _update_cost() -> void:
	if data == null:
		return
	%CostBadge.visible = data.is_playable()
	if not data.is_playable():
		return
	%CostLabel.text = "%s %s" % [Icons.bb("energy"), _cost_text()]


## Was als Preis dasteht: eine Zahl - oder X, wenn es die Zahl gerade nicht gibt.
##
## X steht nur in der Vorschau, und das ist der Punkt: dort *kann* keine Zahl
## stehen, weil ausserhalb eines Kampfes niemand weiss, wie viel Energie da waere.
## X ist dann keine Verzierung, sondern die einzig ehrliche Angabe.
##
## In der Hand ist die Lage umgekehrt: da steht die Energie fest, und eine Karte,
## die trotzdem X zeigt, verlangt Kopfrechnen fuer etwas, das das Spiel bereits
## weiss. (Erste Fassung vom 02.09.2026 zeigte ueberall X, Korrektur bfn am
## selben Tag.)
func _cost_text() -> String:
	if data.spends_all_energy and preview:
		return "X"
	return str(cost)


## Schreibt die Beschreibung.
##
## Zahlen und Icons wandern im selben format()-Aufruf in den Text. Eine .tres
## schreibt also "{icon_dmg} {damage} Schaden" - Beschreibungen ohne
## Icon-Platzhalter funktionieren unveraendert weiter.
##
## `{times}` kommt hier dazu und nicht aus CardEffect.values_from(): wie oft eine
## Wirkung ausloest, haengt bei einer X-Karte am Preis, und den kennt nur diese
## Ansicht. Alles andere in dem Dictionary steht in der Resource.
func _update_text() -> void:
	if data == null:
		return
	var values := data.description_values()
	values["times"] = _cost_text()
	%TextLabel.text = Icons.fill(data.description, values)


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
