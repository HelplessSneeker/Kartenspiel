#!/usr/bin/env python3
"""Bringt die Kartenbilder auf einen gemeinsamen Ton.

Warum es das gibt: die Bilder kommen aus voellig verschiedenen Quellen - ein
koerniges Filmstill neben einem freigestellten Produktfoto auf reinweissem
Studiohintergrund. Nebeneinander in einer Hand liest sich das als
zusammengesucht, und die weissen Flaechen leuchten in einer dunklen
Oberflaeche wie Loecher.

Der Ablauf ist bewusst eine Datei und kein Godot-Shader: die Bilder aendern
sich nie zur Laufzeit, also kann die Arbeit einmal beim Einpflegen passieren
statt sechzigmal pro Sekunde. Ausserdem sieht man das Ergebnis dann in der
Datei und nicht erst im laufenden Spiel.

Benutzung:

    PYTHONPATH=/tmp/pilenv python3 tools/grade_art.py

Liest `art_src/*.jpg` und schreibt nach `assets/art/`. Die Originale bleiben in
`art_src/` liegen - dort steht ein `.gdignore`, damit Godot den Ordner gar
nicht erst anfasst und die Rohbilder nicht im Export landen.

WICHTIG: nie ueber ein bereits behandeltes Bild laufen lassen, sonst wird die
Behandlung doppelt angewandt. Neue Kartenbilder gehoeren nach `art_src/`, nicht
direkt nach `assets/art/`.
"""

import pathlib
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

SRC = pathlib.Path("art_src")
DST = pathlib.Path("assets/art")

# Die Groesse bleibt, wie sie ist - hier wird nur getont, nicht zugeschnitten.
# Das ist wichtig, weil in demselben Ordner zwei Formate liegen: Kartenbilder
# sind 220x160 (doppelter Rahmen aus card.tscn), Portraets 240x280. Ein
# gemeinsames Zielformat wuerde die Portraets platt druecken. Zuschneiden
# gehoert ohnehin ins Bild selbst, nicht in diesen Durchlauf.

# Wie stark die Farbe zurueckgenommen wird. Nicht auf 0: die Bilder sollen
# zusammengehoeren, nicht farblos werden - ein blaues Sofa darf blau bleiben.
SATURATION = 0.66

# Der Tonwertumfang, auf den alles gestaucht wird. Das ist der eigentliche
# Trick: kein Pixel ist danach mehr reines Weiss, also hoert der weisse
# Studiohintergrund auf zu leuchten. Kein reines Schwarz, damit das dunkle
# Filmstill nicht in der Karte absaeuft.
BLACK, WHITE = 20, 172

# Warme Toenung, pro Kanal. Blau wird am staerksten zurueckgenommen - das ist
# die Richtung "Gluehbirne in einer Stube", also der Ort, an dem das Spiel
# spielt.
TINT = (1.04, 0.99, 0.88)

# Koernung. Der zweite Grund, warum die Bilder zusammengehoeren: eine
# gemeinsame Textur ueberdeckt, dass das eine Bild scharf und das andere weich
# ist. 0.07 ist wenig - sichtbar erst, wenn man sucht.
GRAIN = 0.07
GRAIN_SIGMA = 10

# Wie dunkel die Ecken werden. Zieht den Blick in die Bildmitte und laesst das
# Bild in den Kartenrahmen auslaufen, statt hart daran zu enden.
VIGNETTE = 0.42


def build_lut() -> list[int]:
    """Die Farbtabelle fuer Stauchung und Toenung in einem Schritt.

    Zusammengelegt und nicht nacheinander, weil jeder eigene point()-Durchgang
    auf 8 Bit rundet - zwei Durchgaenge sind zwei Rundungsfehler.
    """
    lut: list[int] = []
    for channel in TINT:
        for i in range(256):
            value = BLACK + (WHITE - BLACK) * (i / 255.0)
            lut.append(max(0, min(255, round(value * channel))))
    return lut


def vignette_mask(size: tuple[int, int]) -> Image.Image:
    """Weiche runde Maske: innen weiss (Bild bleibt), aussen schwarz (dunkel).

    Ueber ein kleines Bild gebaut und dann hochskaliert. Der Weichzeichner
    arbeitet dadurch auf 64x64 statt auf voller Groesse, und die Kante wird
    beim Skalieren ohnehin weich - zweimal weich ist genau richtig.
    """
    small = Image.new("L", (64, 64), 0)
    # Groesser als das Bild gezeichnet: sonst liegt die dunkle Zone schon in
    # der Bildmitte statt erst in den Ecken.
    ImageDraw.Draw(small).ellipse((-4, -4, 68, 68), fill=255)
    small = small.filter(ImageFilter.GaussianBlur(13))
    return small.resize(size, Image.LANCZOS)


def grade(image: Image.Image) -> Image.Image:
    image = image.convert("RGB")
    image = ImageEnhance.Color(image).enhance(SATURATION)
    image = image.point(build_lut())

    noise = Image.effect_noise(image.size, GRAIN_SIGMA).convert("L")
    image = Image.blend(image, Image.merge("RGB", (noise, noise, noise)), GRAIN)

    dark = ImageEnhance.Brightness(image).enhance(VIGNETTE)
    image = Image.composite(image, dark, vignette_mask(image.size))

    return image


def main() -> int:
    if not SRC.is_dir():
        print(f"{SRC} fehlt - Rohbilder gehoeren dorthin.", file=sys.stderr)
        return 1

    DST.mkdir(parents=True, exist_ok=True)
    count = 0
    for path in sorted(SRC.glob("*.jpg")):
        out = DST / path.name
        grade(Image.open(path)).save(out, "JPEG", quality=88, optimize=True)
        print(f"{path} -> {out}")
        count += 1

    if count == 0:
        print(f"Keine .jpg in {SRC} gefunden.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
