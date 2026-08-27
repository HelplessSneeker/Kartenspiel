class_name FloatingNumber
extends Label

## Eine Zahl, die kurz ueber einem Kaempfer aufsteigt und verblasst.
##
## Warum ueberhaupt? Der Lebensbalken sagt, wie viel *uebrig* ist. Er sagt nicht,
## wie viel gerade weggegangen ist - und genau das ist die Rueckmeldung auf eine
## gespielte Karte. Vorher musste man den Stand vorher und nachher im Kopf
## behalten, um zu wissen, ob die Watschn etwas gebracht hat.
##
## Die Zahl raeumt sich am Ende selbst weg. Wer die Dauer kennt, soll auch das
## Aufraeumen besitzen - dieselbe Regel wie bei CardView.fly_out().

## Feste Breite, damit die Zahl mittig ueber dem Ziel sitzt.
##
## Ohne sie muesste man die Textbreite abfragen, und die steht erst einen Frame
## nach dem Setzen fest - eine einstellige und eine dreistellige Zahl haetten
## sonst verschiedene Mitten. Zentriert wird ueber horizontal_alignment in der
## .tscn, hier steht nur, worauf zentriert wird.
const WIDTH := 90.0

## Wie weit sie steigt. Knapp ueber Portraethoehe: hoch genug, dass die Bewegung
## als Aufsteigen liest, niedrig genug, dass sie nicht in die Zeile darueber
## wandert.
const RISE := 44.0

const DURATION := 0.85

## Anteil der Dauer, in dem die Zahl noch voll sichtbar ist. Frueheres
## Ausblenden liest sich hektisch: man liest noch, waehrend sie schon weg ist.
const HOLD := 0.6


## Startet Aufstieg und Verblassen. `at` ist der Mittelpunkt in globalen
## Koordinaten, `drift` verschiebt ihn seitlich.
##
## Der Drift ist fuer den Fall, dass in einem Treffer zwei Zahlen entstehen -
## geschluckter Block und durchgekommener Schaden. Uebereinander waeren sie
## unlesbar, und nacheinander waeren sie eine Verzoegerung an der Stelle, an der
## das Spiel gerade schnell sein soll.
func play(value_text: String, color: Color, at: Vector2, drift: float) -> void:
	text = value_text
	modulate = color

	# Container ueberschreiben position und size ihrer Kinder bei jedem
	# Sortieren - und sortiert wird in der HealthView staendig, weil das
	# Blocklabel je nach Blockwert erscheint und verschwindet. top_level nimmt
	# die Zahl aus dieser Rechnung heraus; dafuer sind ihre Koordinaten ab jetzt
	# globale und nicht mehr relativ zum Elternknoten.
	top_level = true
	size = Vector2(WIDTH, 0.0)
	global_position = at + Vector2(drift - WIDTH * 0.5, 0.0)

	var tween := create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", global_position.y - RISE, DURATION)
	tween.tween_property(self, "modulate:a", 0.0, DURATION * (1.0 - HOLD)).set_delay(DURATION * HOLD)
	# chain() haengt hinter *alle* parallelen Tweener, nicht neben sie.
	tween.chain().tween_callback(queue_free)
