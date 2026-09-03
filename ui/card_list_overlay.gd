class_name CardListOverlay
extends Control

## Zeigt eine Liste von Karten in voller Groesse: Ziehstapel, Ablage, Deck.
##
## Ein Overlay fuer alle drei, weil es dreimal dieselbe Frage ist - "was steckt
## da drin". Der Aufrufer sagt nur, wie die Liste heisst und was drin ist; was
## fuer eine Liste das ist, weiss dieses Fenster nicht und braucht es nicht.
##
## Die Karten sind dieselbe card.tscn wie in der Hand. Eine eigene, kleinere
## Ansicht waere platzsparender, hiesse aber, dass eine Karte hier anders
## aussieht als auf dem Tisch - und dann muss man beim Nachsehen uebersetzen.
##
## `preview` bleibt auf seiner Voreinstellung true (siehe card.gd): eine X-Karte
## zeigt hier X. In einer Liste steht keine Energie zur Verfuegung, gegen die man
## rechnen koennte - dieselbe Ueberlegung wie bei der Belohnungsauswahl.

const CARD_SCENE := preload("res://cards/card.tscn")

## Wie viele Kartenreihen zu sehen sind, bevor gescrollt wird.
##
## Die Hoehe des Scrollbereichs wird daraus gerechnet statt im Inspector
## festgenagelt: bei drei Karten in der Ablage soll das Fenster klein sein und
## nicht zwei leere Reihen mittragen. Zwei Reihen (bei fuenf Spalten also zehn
## Karten) passen bei 720 Pixel Hoehe zusammen mit Titel und Knopf ins Bild.
const MAX_ROWS := 2


func _ready() -> void:
	hide()


## Escape schliesst das Fenster - und *nur* das.
##
## Ueber _input() und nicht _unhandled_input(), obwohl das Pausenmenue es
## andersherum macht. Godot ruft _input() vor _unhandled_input(): das Fenster
## bekommt die Taste damit garantiert zuerst und kann sie mit
## set_input_as_handled() abfangen, bevor das Pausenmenue sie sieht. Lauschten
## beide auf _unhandled_input, entschiede die Reihenfolge im Szenenbaum, wer
## zuerst drankommt - und die aendert sich beim naechsten Umhaengen.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


## Zeigt `cards` unter der Ueberschrift `list_title`.
##
## `cards` wird kopiert, bevor sortiert wird. Das ist keine Vorsicht, sondern
## Pflicht: sort_custom() sortiert an Ort und Stelle, und die uebergebene Liste
## *ist* der Ziehstapel des laufenden Kampfes. Ohne die Kopie waere ein Blick in
## den Stapel ein Eingriff in die Ziehreihenfolge.
func open(list_title: String, cards: Array[CardData]) -> void:
	Sfx.play("click")
	%TitleLabel.text = list_title

	_clear()
	# Ausgeschrieben statt per := abgeleitet: duplicate() ist als Array
	# deklariert, der abgeleitete Typ waere also untypisiert - und _sort_before
	# bekaeme seine Argumente ungeprueft.
	var sorted: Array[CardData] = cards.duplicate()
	sorted.sort_custom(_sort_before)
	for data in sorted:
		_add_card(data)

	var empty := sorted.is_empty()
	%EmptyLabel.visible = empty
	%Scroll.visible = not empty
	if not empty:
		_fit_scroll()

	show()
	%CloseButton.grab_focus()


func close() -> void:
	Sfx.play("click")
	hide()
	# Die Karten bleiben nicht liegen. Ein Deck mit dreizehn Kartenansichten im
	# Speicher zu halten, waehrend das Fenster zu ist, kostet nichts Spuerbares -
	# aber die naechste Oeffnung muesste sie trotzdem alle wegraeumen, weil sich
	# der Inhalt geaendert haben kann. Dann lieber gleich hier.
	_clear()


## Die Sortierung - und der Grund, warum es sie gibt.
##
## Der Ziehstapel liegt in game.gd in genau der Reihenfolge, in der gezogen
## wird. Wuerde er hier so angezeigt, waere das keine Uebersicht mehr, sondern
## ein Blick auf die naechsten fuenf Karten - und jede Entscheidung, die sich
## darauf stuetzt, was *kommen koennte*, waere erledigt. Slay the Spire macht es
## aus demselben Grund so: man erfaehrt, was noch drin ist, nicht wann es kommt.
##
## Deshalb sortiert dieses Fenster selbst und laesst dem Aufrufer nicht die Wahl.
## Eine Liste, deren Reihenfolge etwas verraet, soll man hier gar nicht
## hineinreichen koennen.
##
## Sortiert wird nach Art, dann Preis, dann Name: so stehen die Angriffe
## beieinander, und innerhalb davon die billigen vorn. Dass identische Karten
## dabei nebeneinander landen, ist der eigentliche Nutzen - "wie viele Watschn
## sind noch drin" liest man dann ab, statt zu suchen.
func _sort_before(a: CardData, b: CardData) -> bool:
	if a == null or b == null:
		return a != null
	if a.type != b.type:
		return a.type < b.type
	if a.cost != b.cost:
		return a.cost < b.cost
	return a.card_name < b.card_name


func _add_card(data: CardData) -> void:
	if data == null:
		return
	var view: CardView = CARD_SCENE.instantiate()
	%Grid.add_child(view)
	view.setup(data)


## Setzt die Hoehe des Scrollbereichs auf so viele Reihen, wie es gibt -
## hoechstens MAX_ROWS.
##
## Muss gerechnet werden und kann nicht im Inspector stehen: eine feste Zahl
## waere entweder zu klein fuer ein volles Deck oder zu gross fuer eine Ablage
## mit drei Karten, und im zweiten Fall stuende das halbe Fenster leer.
##
## Gerechnet wird aus der Gesamthoehe des Rasters, nicht aus der Hoehe der
## ersten Karte. Die erste Fassung tat Letzteres und lag deshalb daneben: eine
## Karte mit zweizeiligem Text ist hoeher als eine mit einzeiligem, und eine
## Reihe ist so hoch wie ihre hoechste Karte. Bei zehn Karten fehlten dadurch
## ein paar Pixel - zu wenig, um es zu sehen, aber genug, dass der Bereich
## scrollbar war, ohne dass es etwas zu scrollen gab. (Befund bfn, 03.09.2026)
##
## Passt alles, bekommt der Ausschnitt exakt die Inhaltshoehe. Dann gibt es
## nichts zu scrollen und Godot blendet den Balken von selbst aus.
func _fit_scroll() -> void:
	var count := %Grid.get_child_count()
	if count == 0:
		return

	var content: float = %Grid.get_combined_minimum_size().y
	var rows := ceili(float(count) / float(%Grid.columns))
	if rows <= MAX_ROWS:
		%Scroll.custom_minimum_size.y = content
		return

	# Anteilig kuerzen: eine mittlere Reihenhoehe ist hier die ehrlichere Zahl
	# als die irgendeiner einzelnen Karte, und auf ein paar Pixel kommt es beim
	# Abschneiden nicht an - der Balken sagt ohnehin, dass es weitergeht.
	var separation: int = %Grid.get_theme_constant("v_separation")
	var per_row := (content - (rows - 1) * separation) / float(rows)
	%Scroll.custom_minimum_size.y = MAX_ROWS * per_row + (MAX_ROWS - 1) * separation


func _clear() -> void:
	for child in %Grid.get_children():
		child.queue_free()
		# Aus dem Baum nehmen, nicht nur zum Wegraeumen vormerken: queue_free()
		# wirkt erst am Ende des Frames, und bis dahin zaehlen die alten Karten
		# noch bei get_child_count() mit. Das naechste Oeffnen wuerde sonst mit
		# der Summe aus alt und neu rechnen.
		%Grid.remove_child(child)


# --- Signale ------------------------------------------------------------------

func _on_close_button_pressed() -> void:
	close()


## Ein Klick neben den Dialog schliesst ebenfalls.
##
## Der abgedunkelte Hintergrund faengt Klicks ohnehin ab, damit sie nicht auf
## den Karten darunter landen - er kann sie also genauso gut benutzen. Bei einem
## Fenster, das nur etwas anzeigt und nichts entscheidet, ist "danebentippen" die
## erwartete Art zuzumachen.
func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
