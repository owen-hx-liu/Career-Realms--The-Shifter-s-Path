#!/bin/bash
# Launch the FBLA game with the local Godot 4.4.1 (mono) build.
# Usage:
#   ./run-game.sh          # run the game
#   ./run-game.sh --editor # open the Godot editor instead
GODOT="$HOME/Downloads/Godot_mono.app/Contents/MacOS/Godot"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -x "$GODOT" ]; then
  echo "Godot not found at: $GODOT" >&2
  echo "Edit run-game.sh and point GODOT at your Godot 4.4.x binary." >&2
  exit 1
fi

if [ "$1" == "--editor" ]; then
  exec "$GODOT" --editor --path "$PROJECT_DIR"
else
  # Pass any extra args through, e.g. a scene path to boot directly into:
  #   ./run-game.sh res://scenes/world_scenes/AlienBioengineeringQuest.tscn
  exec "$GODOT" --path "$PROJECT_DIR" "$@"
fi
