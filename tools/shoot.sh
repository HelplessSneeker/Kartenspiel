#!/usr/bin/env bash
# Screenshot einer Szene, auf einem Rechner ohne Bildschirm.
#
#     tools/shoot.sh res://scenes/ui/main_menu.tscn /tmp/menu.png [frames]
#
# Startet einen virtuellen Bildschirm (Xvfb), laesst Godot mit Mesas
# Software-Renderer hineinzeichnen und ruft tools/shoot.gd auf, das das Bild
# herausschreibt. Siehe die Kommentare dort fuer das Warum.
#
# Fallstricke, die hier schon eingebaut sind:
#
# - `xvfb-run` geht auf primus NICHT: es braucht `xauth`, und das ist nicht
#   installiert. Deshalb Xvfb von Hand starten und wieder abraeumen.
# - Der Skriptpfad braucht das `res://`-Praefix. Ohne findet Godot die Datei
#   nicht, obwohl `--path` stimmt.
# - `--headless` waere falsch - das zeichnet gar nicht, das Bild bliebe schwarz.
# - LIBGL_ALWAYS_SOFTWARE erzwingt llvmpipe; ohne GPU gaebe es sonst je nach
#   Treiberlage einen Fehlschlag statt eines langsamen Bildes.
set -euo pipefail

GODOT="${GODOT:-$HOME/Applications/godot-4.7.1/Godot_v4.7.1-stable_linux.x86_64}"
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISPLAY_NUM="${DISPLAY_NUM:-99}"
SIZE="${SIZE:-1280x720x24}"

SCENE="${1:?Aufruf: shoot.sh <res://szene.tscn> <ziel.png> [frames]}"
OUT="${2:?Aufruf: shoot.sh <res://szene.tscn> <ziel.png> [frames]}"
FRAMES="${3:-40}"

Xvfb ":$DISPLAY_NUM" -screen 0 "$SIZE" -nolisten tcp >/dev/null 2>&1 &
XVFB_PID=$!
trap 'kill "$XVFB_PID" 2>/dev/null || true' EXIT
sleep 2

DISPLAY=":$DISPLAY_NUM" LIBGL_ALWAYS_SOFTWARE=1 \
	"$GODOT" --path "$PROJECT" \
	--rendering-driver opengl3 --audio-driver Dummy \
	--script res://tools/shoot.gd ++ "$SCENE" "$OUT" "$FRAMES"
