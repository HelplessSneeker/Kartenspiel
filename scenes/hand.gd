class_name Hand
extends Control

## Die Karten auf der Hand - und ihr Weg vom Ziehstapel hierher und zur Ablage.
##
## WICHTIGE ÄNDERUNG gegenueber vorher: die Hand baut sich nicht mehr bei jeder
## Zustandsaenderung komplett neu. `set_cards()` war bequem - "hier ist der
## Zustand, mach was draus" -, konnte aber prinzipiell nichts animieren: wer
## jedes Mal alles wegwirft und neu baut, weiss nie, *was* sich geaendert hat.
## Eine Karte, die zur Ablage fliegen soll, muss aber dieselbe Karte sein, die
## eben noch in der Hand lag.
##
## Deshalb bekommt die Hand jetzt Verben statt eines Zustands: austeilen,
## ablegen, alles abwerfen. game.gd bleibt die einzige Quelle der Wahrheit -
## es sagt der Hand, was passiert ist, statt nur, wie es danach aussieht.

## Reicht den Klick nach oben durch. Die Hand kennt keine Spielregeln -
## sie zeigt Karten an und meldet, wenn eine angeklickt wurde.
##
## Gemeldet wird die View, nicht mehr nur ihre Daten: das Deck enthaelt fuenfmal
## dieselbe Angriffskarte, alle fuenf sind dieselbe Resource. Aus den Daten
## allein liesse sich nicht sagen, *welche* der drei Karten auf dem Tisch
## gemeint ist - und genau die soll gleich zur Ablage fliegen.
signal card_clicked(view: CardView)

## Die gespielte Karte ist an ihrem Ziel angekommen. game.gd wartet darauf,
## bevor es die Wirkungen ausfuehrt - damit die Zahl aufsteigt, wenn die Karte
## einschlaegt, und nicht schon beim Klick.
signal card_struck

const CARD_SCENE := preload("res://cards/card.tscn")

## Abstand zwischen zwei Karten, solange genug Platz ist.
@export var spacing := 12.0

## Abstand der Kartenunterkante zum unteren Bildschirmrand, wenn die Hand ruht.
@export var idle_offset := 0.0

## Dasselbe, solange die Maus in der Hand ist. Beide Zustaende haben bewusst
## ihre eigene Zahl - vorher hingen sie aneinander und liessen sich nicht
## unabhaengig einstellen.
@export var active_offset := 25.0

## Groesse der Karten im Ruhezustand.
@export var idle_scale := 0.8

## Groesse der Karte unter dem Cursor.
@export var hover_scale := 1.25

## Zusaetzlicher Hub der Karte unter dem Cursor. Default 0 - siehe Kommentar
## in _apply_layout(), das Ding kann Hover-Flackern ausloesen.
@export var hover_lift := 0.0

## Dauer der Uebergaenge innerhalb der Hand (zusammenruecken, hovern).
@export var tween_time := 0.12

## Woher Karten kommen und wohin sie gehen. Zeigt auf die beiden Pile-Knoten.
##
## Als NodePath und nicht als zwei Vector2 im Inspector: zieht man den Stapel
## im Editor um, wandert der Flugweg mit. Zwei von Hand gepflegte Zahlen waeren
## am ersten Layout-Umbau falsch, ohne dass es jemand merkt.
@export var deck_pile_path: NodePath
@export var discard_pile_path: NodePath

## Dauer eines Fluges zwischen Stapel und Hand. Deutlich laenger als
## tween_time - eine Bewegung, die man verfolgen koennen soll, darf nicht so
## schnell sein wie eine, die nur nicht ruckeln soll.
@export var travel_time := 0.3

## Dasselbe fuer eine Karte, die *mitten im Zug* nachgezogen wird.
##
## Eigene Zahl statt travel_time mitzubenutzen, weil es ein anderer Moment ist:
## beim Zugbeginn erwartet man fuenf Karten und weiss, wo man hinsieht. Mitten
## im Zug kommt eine dazu, waehrend die Aufmerksamkeit woanders ist - das darf
## laenger dauern. Zwei getrennte Regler heisst auch: das Austeilen laesst sich
## beschleunigen, ohne das Nachziehen wieder unsichtbar zu machen.
@export var draw_travel_time := 0.45

## Versatz zwischen zwei Karten beim Austeilen.
@export var deal_delay := 0.08

## Groesse einer Karte, solange sie auf einem Stapel liegt.
@export var pile_scale := 0.55

## Wie lange die gespielte Karte zu ihrem Ziel unterwegs ist.
##
## Kurz gehalten, weil das Spiel in dieser Zeit keine Eingabe annimmt: die Karte
## wirkt erst beim Einschlag, also muss bis dahin gewartet werden. Bei 0,18 s
## liest sich das als Gewicht, ab etwa einer halben Sekunde als Haenger - und
## wer drei Karten hintereinander spielt, merkt den Unterschied deutlich.
## Auf 0 gesetzt wirkt die Karte praktisch sofort, der Flug bleibt sichtbar.
@export var strike_time := 0.18

## Wie lange die Karte am Ziel stehen bleibt, bevor sie zur Ablage weiterfliegt.
##
## Ohne diese Pause faellt der Einschlag mit dem Abflug zusammen, und das Auge
## sieht nur eine durchgehende Bewegung quer ueber den Bildschirm. Das Spiel
## nimmt waehrend der Pause bereits wieder Eingaben an - sie kostet also nichts.
@export var strike_hold := 0.1

## Feinjustierung des Zielpunkts, in Pixeln.
##
## game.gd sagt nur, *wer* getroffen wird, und liefert die Mitte von dessen
## Anzeige. Ob die Karte etwas tiefer besser sitzt, ist eine Frage des Augenmasses
## - und die kann ich nicht beantworten, weil ich das Spiel nie laufen sehe.
## Deshalb steht die Zahl im Inspector und nicht im Code.
@export var strike_offset := Vector2(0.0, 40.0)

## Wie die Hand herausfindet, was eine Karte kostet. Wird von game.gd gesetzt.
##
## Die Hand kennt keine Spielregeln, und "was kostet das gerade" ist eine -
## seit es Karten gibt, die im Kampf teurer werden, steht die Antwort nicht mehr
## in der CardData. Ohne gesetzten Wert faellt _card_cost() auf den Grundpreis
## zurueck, damit die Szene auch allein geoeffnet noch etwas Vernuenftiges zeigt.
var cost_lookup: Callable

var _views: Array[CardView] = []
var _hovered: CardView = null

## True, sobald die Maus irgendwo im Hand-Rechteck ist.
var _active := false

## Sperre gegen den eigenen Wiedereintritt, siehe _apply_layout().
var _laying_out := false


func _ready() -> void:
	mouse_entered.connect(_on_hand_mouse_entered)
	mouse_exited.connect(_on_hand_mouse_exited)
	resized.connect(_apply_layout.bind(false))


# --- Verben -------------------------------------------------------------------

## Teilt eine frische Hand aus. Die Karten starten auf dem Ziehstapel und
## fliegen nacheinander an ihren Platz.
##
## `energy` entscheidet nur, welche Karten als spielbar aussehen - die echte
## Regel liegt weiterhin in game.gd.
func deal(cards: Array[CardData], energy: int) -> void:
	# Erwartet eine leere Hand. Ist doch noch etwas da, gehoert es weg -
	# lieber hier abgeraeumt als spaeter als Geisterkarte gesucht.
	if not _views.is_empty():
		discard_all()

	for data in cards:
		_make_view(data, energy)

	if _views.is_empty():
		return

	# Erst die Hand auf ihre Hoehe ziehen, dann die Startpunkte ausrechnen.
	# _pile_position() rechnet den Stapel aus globalen in Hand-Koordinaten um -
	# und die Hand verschiebt sich beim ersten Austeilen um ihre eigene Hoehe
	# nach oben. Andersherum starteten die Karten beim allerersten Zug rund 240
	# Pixel daneben, ab dem zweiten aber richtig: der unangenehme Fehler, der
	# nur einmal auftritt und deshalb wie ein Zufall aussieht.
	_fit_self(_views[0].size.y)

	# Startpunkt: der Ziehstapel. Von dort holt _apply_layout() sie ab.
	for view in _views:
		view.snap_to(_pile_position(deck_pile_path, 0.0, view.size), Vector2.ONE * pile_scale)

	# Kein Vorlauf: die Hand war leer, es muss niemand Platz machen.
	_apply_layout(true, _views.duplicate(), travel_time, 0.0)


## Karten, die mitten im Zug dazukommen - eine Karte hat "ziehe N" ausgeloest.
##
## Eigenes Verb neben deal(), obwohl beides "Karten erscheinen" heisst: deal()
## setzt eine Hand *neu* auf und raeumt vorher weg, was noch liegt. Hier liegt
## etwas, und es soll liegen bleiben; die neuen Karten schieben sich dazwischen
## und alles rueckt zusammen.
##
## Das Nachziehen laeuft in zwei Schritten, nicht in einem. Vorher wurde die
## ganze Hand gestaffelt bewegt - die alten Karten ruckelten also im selben
## Takt zur Seite, in dem die neuen ankamen, und weil zusaetzlich noch die
## gespielte Karte zur Ablage flog, war fuer eine halbe Sekunde einfach alles
## in Bewegung. Zwei neue Karten gingen darin unter.
##
## Jetzt: erst ruecken die vorhandenen Karten zusammen (kurz, tween_time), und
## *danach* fliegen die neuen ein. Der Blick sieht zuerst eine Luecke entstehen
## und weiss, wo etwas passieren wird, bevor es passiert.
func draw_in(cards: Array[CardData], energy: int) -> void:
	if cards.is_empty():
		return

	var arrived: Array[CardView] = []
	for data in cards:
		arrived.append(_make_view(data, energy))

	# Startpunkt Ziehstapel - nur fuer die neuen. Die alten stehen schon, wo sie
	# stehen, und werden von _apply_layout() von dort abgeholt.
	for view in arrived:
		view.snap_to(_pile_position(deck_pile_path, 0.0, view.size), Vector2.ONE * pile_scale)

	# Warten muss nur, wer jemanden zur Seite schickt. Zieht eine Karte in eine
	# Hand nach, die gerade leer geworden ist, gibt es keine Luecke zu machen.
	var lead_in := 0.0 if _views.size() == arrived.size() else tween_time

	_apply_layout(true, arrived, draw_travel_time, lead_in)

	# Ein Ton pro Karte, versetzt wie der Flug: zwei Karten sind zwei Geraeusche.
	# Ein einzelner Ton fuer "ziehe 2" sagt nicht, wie viele es waren - und Ton
	# ist der Hinweis, den man auch mitbekommt, wenn man woanders hinsieht.
	#
	# Hier und nicht in game.gd, obwohl dort sonst alle Toene liegen: *wann* eine
	# Karte losfliegt, weiss nur die Hand. Beim Austeilen bleibt es bewusst bei
	# einem Ton fuer fuenf Karten - fuenfmal derselbe Klick waere ein Maschinengewehr.
	for i in arrived.size():
		_play_delayed("card_draw", lead_in + deal_delay * i)


## Eine gespielte Karte fliegt zu ihrem Ziel und von dort auf die Ablage.
##
## `target_global` ist die Mitte dessen, was getroffen wird - in globalen
## Koordinaten, weil die Lebensanzeigen ausserhalb der Hand im Szenenbaum
## stehen. Wer das Ziel *ist*, entscheidet game.gd; wo dieser Punkt in
## Hand-Koordinaten liegt, ist Sache dieser Datei.
##
## Der Einschlag wird ueber `card_struck` gemeldet und nicht, indem der Aufrufer
## auf den Tween der Karte wartet. Das ist kein Stilempfinden: game.gd haelt bis
## zu diesem Signal jede Eingabe an. Ein Tween kann jederzeit abgeraeumt werden -
## dann kaeme sein `finished` nie, und das Spiel bliebe in einer Sperre stehen,
## aus der kein Weg zurueckfuehrt. Ein SceneTreeTimer feuert immer.
func play_out(view: CardView, target_global: Vector2) -> void:
	_release(view)
	# Die uebrigen Karten ruecken sofort zusammen, nicht erst beim Einschlag.
	# Die Luecke waere sonst eine halbe Sekunde lang zu sehen und saehe aus, als
	# haenge die Hand.
	_apply_layout()

	view.strike(_strike_position(target_global, view.size), strike_time)

	# maxf, damit der Timer nicht auf 0 steht: bei strike_time = 0 wuerde er noch
	# im selben Frame feuern - moeglicherweise bevor game.gd ueberhaupt auf das
	# Signal wartet, und dann wartet es fuer immer.
	get_tree().create_timer(maxf(strike_time, 0.01)).timeout.connect(
		func() -> void:
			card_struck.emit()
			_after_strike(view)
	)


## Nach dem Einschlag: kurz stehen bleiben, dann zur Ablage.
func _after_strike(view: CardView) -> void:
	if strike_hold <= 0.0:
		_to_discard(view)
		return
	get_tree().create_timer(strike_hold).timeout.connect(_to_discard.bind(view))


## Der Zielpunkt in Hand-Koordinaten, umgerechnet auf die Kartenposition.
##
## Abgezogen wird halbe Breite und volle Hoehe, weil `position` die linke obere
## Ecke ist, der Bezugspunkt der Karte aber ihre Unterkante-Mitte (pivot_offset,
## siehe _make_view). Dieselbe Umrechnung wie in _pile_position - dort steht sie
## ausfuehrlicher.
func _strike_position(target_global: Vector2, card_size: Vector2) -> Vector2:
	var anchor := _to_local_point(target_global) + strike_offset
	return anchor - Vector2(card_size.x * 0.5, card_size.y)


## Zugende: die ganze Hand wandert auf die Ablage.
func discard_all() -> void:
	# Ueber eine Kopie, weil _send_to_discard() aus _views entfernt - eine Liste
	# waehrend der eigenen Schleife zu kuerzen ueberspringt jedes zweite Element.
	for view in _views.duplicate():
		_send_to_discard(view)
	_apply_layout()


## Schreibt Preis und Faerbung neu. Baut nichts neu.
##
## Hiess frueher nur "faerbt um". Seit eine Karte im Kampf teurer werden kann,
## muss zum selben Zeitpunkt auch die Plakette nachgezogen werden: game.gd ruft
## das nach jeder Zustandsaenderung, und genau dann hat sich der Preis
## moeglicherweise geaendert. Zwei getrennte Aufrufe waeren zwei Gelegenheiten,
## einen zu vergessen - und die Karte zeigte einen Preis, zu dem sie nicht mehr
## zu haben ist.
func set_energy(energy: int) -> void:
	for view in _views:
		view.cost = _card_cost(view.data)
		view.playable = _is_playable(view.data, energy)


## Ob eine Karte gerade *hell* aussehen darf.
##
## Zwei Gruende, dunkel zu sein, und sie sind verschiedener Natur: zu teuer ist
## voruebergehend und aendert sich mit jeder gespielten Karte, unspielbar ist
## fuer immer. Der Spieler sieht denselben Grauton - das ist Absicht, "damit
## kann ich jetzt nichts anfangen" ist dieselbe Aussage.
##
## Nicht mehr static: der Preis haengt jetzt am Kampf, nicht nur an der Karte.
func _is_playable(data: CardData, energy: int) -> bool:
	return data.is_playable() and _card_cost(data) <= energy


func _card_cost(data: CardData) -> int:
	if cost_lookup.is_valid():
		return cost_lookup.call(data)
	return data.cost


# --- Innenleben ---------------------------------------------------------------

## Baut eine Kartenanzeige und haengt sie in die Hand - ohne sie zu platzieren.
## Das macht danach _apply_layout(), fuer alle Karten auf einmal.
func _make_view(data: CardData, energy: int) -> CardView:
	var view: CardView = CARD_SCENE.instantiate()
	add_child(view)
	view.setup(data)
	# Nach setup(), das den Grundpreis eingesetzt hat, und vor der Groessen-
	# rechnung darunter: eine zweistellige Zahl auf der Plakette macht die Karte
	# minimal breiter, und view.size wird gleich einmalig festgeschrieben.
	view.cost = _card_cost(data)
	view.playable = _is_playable(data, energy)
	# Ohne Container muss die Karte ihre Groesse selbst annehmen.
	view.size = view.get_combined_minimum_size()
	# Skaliert wird um die Unterkante-Mitte: die Karte waechst nach oben
	# und zur Seite, ihr unterer Rand bleibt stehen.
	view.pivot_offset = Vector2(view.size.x * 0.5, view.size.y)
	view.mouse_entered.connect(_on_card_mouse_entered.bind(view))
	view.mouse_exited.connect(_on_card_mouse_exited.bind(view))
	view.clicked.connect(_on_card_clicked)
	_views.append(view)
	return view

## Entlaesst eine Karte aus der Hand, ohne sie schon wegzuschicken.
##
## Sie ist ab sofort keine Handkarte mehr: aus `_views` raus, also rechnet das
## Layout nicht mehr mit ihr, und sie nimmt keine Maus mehr an - sonst koennte
## man eine bereits gespielte Karte nochmal anklicken, waehrend sie unterwegs ist.
##
## Getrennt vom Wegschicken, seit eine gespielte Karte zwei Etappen hat: erst
## zum Ziel, dann zur Ablage. Zwischen beiden gehoert sie niemandem mehr, fliegt
## aber noch.
func _release(view: CardView) -> void:
	_views.erase(view)
	if _hovered == view:
		_hovered = null
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ueber allen anderen, damit der Weg nicht hinter der Hand verschwindet.
	view.z_index = 200


## Letzte Etappe: ab auf die Ablage.
func _to_discard(view: CardView) -> void:
	view.fly_out(
		_pile_position(discard_pile_path, size.x, view.size),
		Vector2.ONE * pile_scale,
		travel_time,
	)


## Beides auf einmal - fuer Karten, die kein Ziel anfliegen (Zugende).
func _send_to_discard(view: CardView) -> void:
	_release(view)
	_to_discard(view)


## Wo eine Karte liegt, wenn sie auf einem Stapel liegt - in Hand-Koordinaten.
##
## Die Stapel stehen ausserhalb der Hand im Szenenbaum, deshalb der Umweg ueber
## die globale Transformation. `fallback_x` greift, solange kein Stapel gesetzt
## ist: dann fliegen die Karten an den unteren Rand statt ins Nichts.
func _pile_position(path: NodePath, fallback_x: float, card_size: Vector2) -> Vector2:
	var anchor := Vector2(fallback_x, size.y)
	var pile := get_node_or_null(path) as Control
	if pile != null:
		anchor = _to_local_point(pile.get_global_rect().get_center())
	# position ist die linke obere Ecke, gemeint ist aber der Punkt, um den
	# skaliert wird - Unterkante-Mitte, siehe pivot_offset.
	return anchor - Vector2(card_size.x * 0.5, card_size.y)


## Rechnet einen globalen Punkt in Hand-Koordinaten um.
##
## Alles, was eine Karte anfliegt, steht ausserhalb der Hand im Szenenbaum -
## die Stapel unten, die Lebensanzeigen oben. Ohne diese Umrechnung waeren die
## Zielpunkte um die Position der Hand daneben, und weil die Hand sich beim
## ersten Austeilen selbst nach oben zieht, waere der Fehler auch noch je nach
## Zeitpunkt verschieden gross.
func _to_local_point(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


## Setzt jede Karte an ihren Platz.
##
## `arriving` sind die Karten, die gerade erst vom Ziehstapel kommen. Sie
## bekommen einen eigenen, laengeren Flug (`arrival_time`) und werden
## gegeneinander versetzt; alle anderen ruecken nur kurz zur Seite. Vorher gab
## es dafuer ein `staggered`-Flag, das fuer die *ganze* Hand galt - genau das
## hat das Nachziehen unsichtbar gemacht.
##
## `lead_in` verzoegert die Ankommenden zusaetzlich, damit die Luecke schon da
## ist, wenn sie ankommen.
##
## `arriving` ist absichtlich untypisiert: es wird nur mit find() gelesen, und
## ein typisierter Default-Parameter ist eine Godot-Feinheit, die ich hier nicht
## nachpruefen kann.
func _apply_layout(
	animate: bool = true,
	arriving: Array = [],
	arrival_time: float = 0.0,
	lead_in: float = 0.0,
) -> void:
	var count := _views.size()
	if count == 0:
		return

	# _fit_self() aendert die eigene Hoehe und loest damit `resized` aus, das
	# wieder hier landet - mit animate = false. Ohne diese Sperre wuerde der
	# geschachtelte Aufruf die Karten sofort an ihr Ziel schnappen, und die
	# Animation, die der aeussere Aufruf gerade starten wollte, waere unsichtbar.
	if _laying_out:
		return
	_laying_out = true

	var card_size: Vector2 = _views[0].size
	_fit_self(card_size.y)

	# Alle Karten ausser der gehoverten haben diese Groesse. Der Abstand muss
	# daran haengen: rechnet man mit der unskalierten Breite, stehen
	# geschrumpfte Karten mit Luecken fuer ihre volle Groesse da.
	var base_scale := 1.0 if _active else idle_scale
	var visible_width := card_size.x * base_scale

	# Abstand von Kartenmitte zu Kartenmitte. Wird es zu eng, ruecken die
	# Karten zusammen und ueberlappen sich.
	var step := visible_width + spacing
	var span := step * (count - 1)
	if span + visible_width > size.x and count > 1:
		step = (size.x - visible_width) / float(count - 1)
		span = step * (count - 1)
	var first_center := (size.x - span) * 0.5

	var base_offset := active_offset if _active else idle_offset

	for i in count:
		var view := _views[i]
		var is_hovered := _active and view == _hovered

		var target_scale := base_scale
		var offset := base_offset
		if is_hovered:
			target_scale = hover_scale
			offset += hover_lift

		# z_index steuert nur die Zeichenreihenfolge, nicht das Layout -
		# im Gegensatz zu move_to_front(), das die Kindreihenfolge aendert.
		#
		# Achtung: das wirkt nicht nur zwischen den Karten, sondern im ganzen
		# Canvas. Eine Karte mit z_index 2 zeichnet auch ueber Geschwister der
		# Hand, die auf 0 stehen - ein Overlay wuerde dann nur die erste Karte
		# verdecken. Was verlaesslich obenauf liegen soll, gehoert deshalb in
		# einen CanvasLayer, siehe OverlayLayer in game.tscn.
		view.z_index = 100 if is_hovered else i
		view.dimmed = not _active

		# pivot_offset sitzt auf Unterkante-Mitte, und genau dieser Punkt bleibt
		# beim Skalieren stehen. Deshalb wird er positioniert, nicht die Ecke.
		var target_pos := Vector2(
			first_center + step * i - card_size.x * 0.5,
			size.y - card_size.y - offset,
		)

		# Der Versatz zaehlt ueber die Ankommenden, nicht ueber die ganze Hand:
		# die erste neue Karte soll sofort nach dem Vorlauf losfliegen, egal wie
		# viele Karten schon auf dem Tisch liegen.
		var arrival := arriving.find(view)
		var duration := tween_time
		var delay := 0.0
		if arrival >= 0:
			duration = arrival_time
			delay = lead_in + deal_delay * arrival

		_move_to(view, target_pos, Vector2.ONE * target_scale, animate, duration, delay)

	_laying_out = false


## Die Hand zieht sich selbst auf die noetige Hoehe, statt sie aus einer von
## Hand gesetzten Inspector-Zahl zu beziehen - bei Hoehe 0 lagen die Karten
## unterhalb des Bildschirms. Der Zuschlag fuer hover_scale sorgt dafuer, dass
## auch die vergroesserte Karte noch im Rechteck liegt und die Maus-Erkennung
## nicht abreisst.
## Setzt Anchor-Preset "Bottom Wide" voraus (anchor_top == anchor_bottom == 1).
func _fit_self(card_height: float) -> void:
	var wanted := card_height * maxf(1.0, hover_scale) + maxf(idle_offset, active_offset)
	if is_equal_approx(size.y, wanted):
		return
	offset_top = -wanted
	offset_bottom = 0.0


## Spielt einen Ton erst in `delay` Sekunden.
##
## Ueber einen SceneTreeTimer und nicht ueber den Tween der Karte: der Tween
## gehoert der Karte und wird beim naechsten Layout-Wechsel abgeraeumt - ein
## Hover mitten im Flug wuerde den Ton verschlucken.
func _play_delayed(sound: String, delay: float) -> void:
	if delay <= 0.0:
		Sfx.play(sound)
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void: Sfx.play(sound))


func _move_to(
	view: CardView,
	pos: Vector2,
	card_scale: Vector2,
	animate: bool,
	duration: float,
	delay: float,
) -> void:
	if animate:
		view.animate_to(pos, card_scale, duration, delay)
	else:
		view.snap_to(pos, card_scale)


# --- Signale ------------------------------------------------------------------

func _on_hand_mouse_entered() -> void:
	_active = true
	_apply_layout()


func _on_hand_mouse_exited() -> void:
	_active = false
	_hovered = null
	_apply_layout()


func _on_card_mouse_entered(view: CardView) -> void:
	_active = true
	_hovered = view
	_apply_layout()


func _on_card_mouse_exited(view: CardView) -> void:
	if _hovered != view:
		return
	_hovered = null
	# Eine vergroesserte Karte kann ueber den Rand der Hand hinausragen. Verlaesst
	# der Cursor sie dort, feuert `mouse_exited` der Hand nie - deshalb hier
	# selbst nachsehen, statt auf das Signal zu warten.
	_active = get_global_rect().has_point(get_global_mouse_position())
	_apply_layout()


func _on_card_clicked(view: CardView) -> void:
	card_clicked.emit(view)
