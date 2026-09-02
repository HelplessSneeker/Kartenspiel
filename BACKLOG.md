# Backlog

Was liegen bleibt, bis es dran ist. Details zu allem Rechtlichen stehen ausführlich
in [ASSETS.md](ASSETS.md) — hier steht nur, was zu tun ist.

## Blocker vor dem ersten Release (rechtlich)

Nichts davon hindert am Weiterbauen. Alles davon hindert an einer Veröffentlichung.

- [ ] **`assets/art/spieler.jpg` und `assets/art/balg.jpg` ersetzen.** Herkunft und Lizenz
      ungeklärt, und beide zeigen erkennbare reale Personen. Das ist zweimal ein Problem:
      Urheberrecht am Bild *und* Persönlichkeitsrecht der Abgebildeten — Letzteres deckt
      keine Bildlizenz ab, auch CC0 nicht.
- [ ] **`assets/art/watschn.jpg` ersetzen.** Trailer-Screenshot von 1954, „Public domain"
      gilt nur nach **US**-Regel (vor 1978 ohne Copyright-Vermerk veröffentlicht). Für
      einen Release aus Österreich zählt EU-Recht: 70 Jahre nach Tod des Urhebers. Plus
      erkennbare Person.
- [ ] **Quelle und Lizenz für `assets/audio/sfx/watschn.ogg` und `bier.ogg` klären.**
      Von bfn beigesteuert, Herkunft ist nirgends dokumentiert. In `ASSETS.md` stehen
      dort Fragezeichen. Entweder eintragen (falls CC0/CC-BY: Namensnennung prüfen) oder
      ersetzen.
- [ ] **Die sechs Kartenbilder vom 02.09.2026 ersetzen** — `bier.jpg`, `guertel.jpg`,
      `voll_durchziehen.jpg`, `watschen_bam.jpg`, `zirbn.jpg`, `schem_schem.jpg`. Alle von
      bfn beigesteuert, Herkunft und Lizenz ungeklärt. Drei Sorten Problem, Details in
      `ASSETS.md`: erkennbare reale Personen in einer Gewaltdarstellung (`guertel`,
      `voll_durchziehen`), lesbare Marken (`bier` = Krombacher, `zirbn` = Produktetikett),
      und vermutlich Stock-Material ohne Lizenz.
- [ ] **`assets/art/tschick.jpg` gegenprüfen.** Commons-Bild, aber dieselbe
      „Public domain heißt oft nur US-gemeinfrei"-Falle wie bei `watschn.jpg`.
      (`bier.jpg` stand hier auch — ist am 02.09.2026 ersetzt worden und jetzt ein
      anderer Fall, siehe Punkt darüber.)
- [ ] **Die zwei Hintergründe sind CC BY-SA 4.0 — das ist der schwerste Punkt hier.**
      `assets/art/bg/stube.jpg` (Chris Walch) und `bg/kuechl.jpg` (Hubertl). Namensnennung
      allein reicht bei **ShareAlike nicht**: die Lizenz verlangt, dass Bearbeitungen
      unter derselben Lizenz weitergegeben werden. Wie weit das auf ein Spiel durchschlägt,
      in dem das Bild nur eine Textur unter vielen ist, ist eine juristische Frage und
      keine, die man im Repo beantwortet. **Für einen kommerziellen Release ersetzen** —
      am saubersten durch ein eigenes Foto, dann ist die Frage komplett weg.
      Zum Bauen sind sie in Ordnung, deshalb liegen sie drin.

Namensnennung ist dagegen **erledigt**: game-icons.net (Lorc, sbed) und incompetech
(Kevin MacLeod, mit dem vorgeschriebenen Wortlaut pro Titel) stehen im Credits-Screen,
Kenney ebenfalls.

## Housekeeping

- [ ] **`.import`-Dateien committen** für alles in `assets/art/` außer `watschn.jpg` —
      also `balg.jpg`, `bier.jpg`, `spieler.jpg`, `tschick.jpg` und die fünf neuen
      (`guertel`, `voll_durchziehen`, `watschen_bam`, `zirbn`, `schem_schem`). Godot legt
      sie beim Öffnen des Projekts an; ignoriert gehören laut Godot-Doc nur `.godot/`,
      `*.translation` und `export_presets.cfg`.
- [ ] **`.uid`-Dateien** für die neuen Skripte (`combat/enemy_data.gd`,
      `run/run_config.gd`, `run/run_state.gd`) — gleiche Sache, entstehen beim Öffnen.
- [ ] `combat/actions/hieb.tres`, `deckung.tres`, `wuchtschlag.tres` sind ungenutzt,
      seit der zweite Gegner sein eigenes Moveset hat. Aufräumen oder als Vorlage
      behalten — bewusst noch nicht entschieden.
- [ ] `cards/data/adrenalin.tres` ist wieder ungenutzt (Entscheidung bfn,
      01.09.2026): Name passt nicht ins Setting, und Schem Schem besetzt die
      Rolle „mehr Energie" bereits. Datei liegt noch da — löschen oder als
      Vorlage behalten, gleiche Frage wie oben.

## Kartenbilder — erledigt am 02.09.2026

Jede Karte im Spiel hat jetzt ein `art`. Bilder liegen auf 220×160, also dem Doppelten
des `ArtRect` (110×80). Die Lizenzfrage ist damit **nicht** erledigt, sondern nur
verschoben — siehe den Release-Blocker oben.

## Fehlende Sound-Dateien

Die Slots stehen in `audio/sfx_player.gd`, die Dateien fehlen. Bis dahin bleibt es an
der Stelle still (eine Warnung beim Start, sonst läuft alles):

- [ ] `heulen.ogg`, `bein.ogg`, `mama.ogg`, `schmollen.ogg` — je ein Ton pro
      Gegneraktion. Ein allgemeines „Gegner greift an" wäre der falsche Zuschnitt: in
      einer Komödie ist das Geräusch die halbe Pointe.
