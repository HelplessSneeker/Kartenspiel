# Musik

Hier liegen die Hintergrundstücke. `audio/music_player.gd` erwartet genau
diese zwei Dateinamen:

| Datei | Wo es läuft |
| --- | --- |
| `menu.ogg` | Hauptmenü und Credits |
| `battle.ogg` | im Kampf |

Fehlt eine Datei, bleibt das Spiel still und schreibt beim ersten Versuch eine
Warnung. Kein Absturz — das System steht auch ohne Musik.

## Beim Hinzufügen

- **Format `.ogg`.** Godot importiert es als `AudioStreamOggVorbis`. `.mp3` geht
  auch, `.wav` ist für minutenlange Stücke Verschwendung (unkomprimiert im RAM).
- **Schleife nicht im Import-Dock setzen nötig** — `music_player.gd` schaltet
  `loop` beim Laden selbst ein.
- **Eintrag in `ASSETS.md`** — sofort beim Download, mit Autor und Lizenz.
  Bei CC BY gehört die Namensnennung zusätzlich in `scenes/ui/credits.tscn`.

## Lizenz-Warnung

Auf itch.io heißt „free" oft nur „kostet nichts". Vor dem Download die Terms
der jeweiligen Seite lesen: verlangt sie Namensnennung, ist es CC BY und nicht
CC0 — und verbietet sie kommerzielle Nutzung (NC), ist es für dieses Projekt
unbrauchbar.
