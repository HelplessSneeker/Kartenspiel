#!/usr/bin/env python3
"""Zeichnet die Kartenrueckseite fuer den Ziehstapel.

Warum gezeichnet und nicht heruntergeladen: eine Rueckseite muss zum Theme
passen, nicht umgekehrt. Fertige Packs (Kenney Boardgame) bringen ihre eigene
Farbwelt mit, und die haben wir hier schon zweimal wieder herausgenommen. Ein
paar Linien in genau den Farben, die das Theme ohnehin benutzt, sind billiger
als ein Fremdstil, den man hinterher passend macht.

Warum ueberhaupt ein Bild: der Ziehstapel ist bisher ein leerer Kasten mit
einer Zahl. Eine Rueckseite macht daraus einen Stapel Karten - und das ist der
eine Ort in diesem Spiel, an dem eine Bilddatei etwas kann, was eine StyleBox
prinzipiell nicht kann. Muster mit Diagonalen und Rauten gibt es in
StyleBoxFlat nicht.

Benutzung:

    PYTHONPATH=/tmp/pilenv python3 tools/make_card_back.py

Schreibt `assets/ui/card_back.png`. Laeuft ohne Eingabedateien - wer die Farben
aendern will, aendert die Konstanten hier und laesst es neu laufen.
"""

import pathlib

from PIL import Image, ImageDraw

OUT = pathlib.Path("assets/ui/card_back.png")

# Doppelte Anzeigegroesse. Der Stapel ist 72x106 mit 8 Pixel Innenabstand, die
# Rueckseite fuellt also rund 56x90 - hier viermal so gross, damit sie auch auf
# einem dichten Bildschirm nicht ausfranst.
SIZE = (260, 380)

# Eckenradius. Die Rueckseite liegt *im* Rahmen des Stapels, nicht darunter,
# und braucht deshalb nur leicht gerundete Ecken - der sichtbare Rundungsradius
# gehoert dem Panel darum herum.
RADIUS = 14

BASE = (36, 30, 24)          # dieselbe Familie wie der Stapel-Hintergrund
LATTICE = (60, 50, 40)       # Gitter, knapp ueber dem Grund - nur Textur
GOLD = (138, 112, 72)        # gedaempftes Gold, der Akzent des Themes
GOLD_BRIGHT = (192, 160, 108)

# Abstand der Gitterlinien. Bei Anzeigegroesse sind das rund 6 Pixel - eng
# genug, dass es als Muster liest, weit genug, dass es nicht flimmert.
LATTICE_STEP = 26

# Wie weit der innere Rahmen vom Rand wegbleibt.
INSET = 20


def draw_lattice(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    """Diagonales Gitter in beide Richtungen, auf `box` beschnitten.

    Von Hand beschnitten statt ueber eine Maske: die Linien laufen ohnehin nur
    ueber ein Rechteck, und zwei Schleifen sind hier weniger Umstand als eine
    zweite Ebene mit Alphakanal.
    """
    x0, y0, x1, y1 = box
    width, height = x1 - x0, y1 - y0
    for offset in range(-height, width + height, LATTICE_STEP):
        draw.line([(x0 + offset, y0), (x0 + offset + height, y1)], fill=LATTICE, width=2)
        draw.line([(x0 + offset, y1), (x0 + offset + height, y0)], fill=LATTICE, width=2)


def diamond(center: tuple[int, int], radius: int) -> list[tuple[int, int]]:
    cx, cy = center
    return [(cx, cy - radius), (cx + radius, cy), (cx, cy + radius), (cx - radius, cy)]


def main() -> None:
    width, height = SIZE
    # RGBA, weil die Ecken rund sind: was ausserhalb liegt, muss durchsichtig
    # bleiben, sonst sitzt ein schwarzes Dreieck in jeder Ecke.
    image = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    draw.rounded_rectangle([0, 0, width - 1, height - 1], RADIUS, fill=BASE + (255,))

    inner = (INSET, INSET, width - INSET, height - INSET)

    # Gitter zuerst, Rahmen darueber - so laufen die Linien sauber unter den
    # Rahmen statt an ihm zu enden.
    lattice = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw_lattice(ImageDraw.Draw(lattice), inner)
    mask = Image.new("L", SIZE, 0)
    ImageDraw.Draw(mask).rounded_rectangle(inner, RADIUS // 2, fill=255)
    image.paste(lattice, (0, 0), Image.composite(mask, Image.new("L", SIZE, 0), lattice.split()[3]))

    draw.rounded_rectangle(inner, RADIUS // 2, outline=GOLD + (255,), width=3)

    # Rautenwappen in der Mitte. Zwei ineinander statt einer: eine einzelne
    # Raute sieht aus wie ein vergessener Platzhalter, zwei lesen als Zeichen.
    center = (width // 2, height // 2)
    draw.polygon(diamond(center, 62), outline=GOLD + (255,))
    draw.line(diamond(center, 62) + [diamond(center, 62)[0]], fill=GOLD + (255,), width=3)
    draw.line(diamond(center, 40) + [diamond(center, 40)[0]], fill=GOLD_BRIGHT + (255,), width=2)
    draw.polygon(diamond(center, 16), fill=GOLD + (255,))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT, "PNG", optimize=True)
    print(f"-> {OUT} ({width}x{height})")


if __name__ == "__main__":
    main()
