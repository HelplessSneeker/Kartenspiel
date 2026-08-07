# ASSETS.md

Jedes zugekaufte oder heruntergeladene Asset wird hier eingetragen — **sofort beim
Download**, nicht später. Wer das nachträglich rekonstruieren will, hat verloren.

## Warum das wichtig ist

- **CC0** → nichts zu tun, freie Verwendung inkl. kommerziell.
- **CC BY** → Namensnennung **Pflicht**: im Spiel (Credits-Screen) *und* auf der Store-Seite.
- **CC BY-NC** → nicht-kommerziell. Für ein Spiel, das je Geld kosten soll: **Finger weg.**
- **GPL / CC BY-SA** → Copyleft, färbt ab. Bei Art meist vermeiden.

## Verwendete Assets

| Datei / Ordner | Was | Quelle | Autor | Lizenz | Datum |
| --- | --- | --- | --- | --- | --- |
| `assets/fonts/Oswald.ttf` | Schrift für Kartennamen | [google/fonts `ofl/oswald`](https://github.com/google/fonts/tree/main/ofl/oswald) | Vernon Adams, Kalapi Gajjar, Cyreal | OFL 1.1 (`OFL-Oswald.txt`) | 08.08.2026 |
| `assets/fonts/Inter.ttf` | Schrift für Fließtext & UI | [google/fonts `ofl/inter`](https://github.com/google/fonts/tree/main/ofl/inter) | Rasmus Andersson | OFL 1.1 (`OFL-Inter.txt`) | 08.08.2026 |

Beides **Variable Fonts** mit Weight-Achse — eine Datei deckt alle Schnitte ab.
OFL verlangt, dass der Lizenztext mitgeliefert wird; deshalb liegen die `OFL-*.txt`
neben den Schriften. Namensnennung ist bei OFL **nicht** Pflicht (anders als CC BY),
schadet im Credits-Screen aber nicht.

## Vorgemerkte Quellen

- **Kenney** — https://kenney.nl — durchgehend **CC0**, keine Namensnennung nötig.
  - Board Game Pack (Karten-Blanks, Rückseiten, Chips, Würfel)
  - UI Pack / UI Pack RPG Expansion / Fantasy UI Borders
- **game-icons.net** — ~4000 SVG-Icons, **CC BY 3.0** → Autor pro Icon notieren!
  Godot-Falle: SVG wird beim Import gerastert. Skalierung ins Import-Dock, nicht auf den Node.
- **Google Fonts** — OFL, kommerziell frei.
- **Bfxr / jsfxr** — SFX selbst erzeugen, damit lizenzfrei.
- **Freesound** — gemischte Lizenzen, enthält auch **NC**. Filter setzen und einzeln prüfen.

## Credits-Text (wächst mit)

Sobald das erste CC-BY-Asset drin ist, gehört dieser Block in den Credits-Screen:

```
Icons made by <Autor>. Available on https://game-icons.net (CC BY 3.0)
```
