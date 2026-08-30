class_name EnemyData
extends Resource

## Ein Gegner: wer er ist, wie viel er aushaelt, was er tut.
##
## Bis hierher standen diese Felder als @export in game.gd und wurden in
## game.tscn ausgefuellt - also am *Kampfplatz* statt am Gegner. Das ging genau
## so lange gut, wie es einen Kampf gab. Der Kommentar an `defeat_title` in
## game.gd hat den Moment angekuendigt: "Sobald die Kaempfe eine Reihe bilden,
## zieht das Feld mit dem Gegner in dessen eigene Resource um - zusammen mit
## Leben, Portraet und Muster." Er ist da.
##
## Dieselbe Bauart wie CardData und EnemyAction: Daten in einer .tres, keine
## Logik. Ein neuer Gegner ist eine neue Datei plus ein Eintrag in
## run_config.tres - kein Code.

## Wie er ueber seiner Lebensanzeige heisst.
@export var display_name: String = "Gegner"

## Das Bild ueber der Anzeige. Darf leer bleiben - HealthView blendet das
## PortraitRect dann aus und sieht aus wie vor den Portraets.
@export var portrait: Texture2D

@export var max_health: int = 40

## Was er tut, der Reihe nach und dann wieder von vorn. Leer heisst: er tut
## nichts, und der Kampf laeuft trotzdem (siehe EnemyBrain.plan()).
@export var pattern: Array[EnemyAction] = []

## Was ueber dem Bildschirm steht, wenn der Spieler *diesen* Gegner besiegt.
##
## Ausgeschrieben statt aus dem Namen gebaut ("%s besiegt"). Der Satz ist die
## Pointe des Kampfes, und eine Pointe leitet man nicht ab - dieselbe Begruendung
## wie beim `intent`-Text in EnemyAction.
@export var victory_title: String = "Besiegt"

## Und was dort steht, wenn er den Spieler erledigt.
##
## Gehoert zum Gegner und nicht zum Spieler: gegen den Sohn verliert man nicht,
## indem man stirbt, sondern indem man nachgibt ("Du bleibst daheim"). Ein
## anderer Gegner nimmt einem etwas anderes.
@export var defeat_title: String = "Du bist gefallen"
