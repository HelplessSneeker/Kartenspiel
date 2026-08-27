# Soundeffekte

Gleiche Abmachung wie bei der Musik: **das System steht, die Töne suchst du aus.**
Ich kann nichts anhören und wäre der falsche, der das entscheidet.

`audio/sfx_player.gd` bildet **Ereignisnamen** auf Dateien ab. Der Spielcode ruft
`Sfx.play("heulen")` — er sagt also, *was* passiert ist, nicht *wie* es klingt.
Welche Datei dahinter liegt, steht ausschließlich in `SFX_PATHS`.

## Fehlt noch

| Datei | Wann sie läuft | Ereignisname |
| --- | --- | --- |
| `heulen.ogg` | das Kind heult (Basisangriff) | `heulen` |
| `bein.ogg` | das Kind hängt sich ans Bein | `bein` |
| `mama.ogg` | das Kind ruft nach der Mama | `mama` |
| `schmollen.ogg` | das Kind verkriecht sich (Block) | `schmollen` |

Solange eine Datei fehlt, bleibt es an der Stelle still, es kommt **einmal beim
Start** eine Warnung, und alles andere läuft weiter. Kein Absturz.

## Schon da

| Datei | Wann sie läuft | Ereignisname |
| --- | --- | --- |
| `card-slide-*.ogg` | Karte ziehen (3 Varianten, zufällig) | `card_draw` |
| `card-place-3.ogg` | Karte ausspielen | `card_play` |
| `card-place-2.ogg` | Menü-Klick — **Platzhalter**, siehe `sfx_player.gd` | `click` |
| `error_002.ogg` | zu wenig Energie / unspielbare Karte | `error` |
| `card-shuffle.ogg` | Ablage zurückmischen — **wird bewusst nicht gerufen** | `shuffle` |

## Einen Ton hinzufügen

1. Datei nach `assets/audio/sfx/` legen, **`.ogg`**.
2. In `audio/sfx_player.gd` unter `SFX_PATHS` eintragen. Mehrere Pfade in der
   Liste = zufällige Variante pro Abspielen; das lohnt bei allem, was man
   oft hört (siehe `card_draw`).
3. **Eintrag in `ASSETS.md`** — sofort, mit Autor und Lizenz. Bei CC BY gehört
   die Namensnennung zusätzlich in `scenes/ui/credits.tscn`.

Neue Gegneraktion oder Karte soll klingen? Kein Code nötig — `sound` in ihrer
`.tres` auf den Ereignisnamen setzen. Leer heißt: Karten nehmen den allgemeinen
Legeton, Gegneraktionen bleiben stumm.

## Format

`.ogg`, kurz. `.wav` ginge auch und lädt minimal schneller, kostet dafür
unkomprimiert RAM — bei Effekten unter einer Sekunde ist der Unterschied egal,
also lieber einheitlich `.ogg` wie bei der Musik.

## Lizenz-Warnung

Auf Freesound liegt viel unter CC BY-**NC** — für ein Spiel, das später Geld
kosten könnte, unbrauchbar. Kenney ist CC0 und damit sorglos. Selbst erzeugen
geht mit [jsfxr](https://sfxr.me/) — für Kindergeschrei allerdings nicht.
