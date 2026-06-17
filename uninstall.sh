#!/usr/bin/env bash
set -euo pipefail

PLIST_LABEL="com.notebackup"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
CONFIG_FILE="$HOME/.config/note-backup/config"

ask_yn() {
  local prompt="$1"
  local answer
  while true; do
    read -r -p "$prompt [y/n]: " answer
    case "$answer" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

BOOT_TARGET="gui/$(id -u)"

# Unload the launchd job
if launchctl list "$PLIST_LABEL" &>/dev/null; then
  launchctl bootout "$BOOT_TARGET/$PLIST_LABEL" && echo "Launchd job '$PLIST_LABEL' stopped."
else
  echo "Launchd job '$PLIST_LABEL' is not loaded."
fi

# Remove plist
if [[ -f "$PLIST_PATH" ]]; then
  rm "$PLIST_PATH"
  echo "Removed $PLIST_PATH"
fi

# Optionally remove config
if [[ -f "$CONFIG_FILE" ]]; then
  if ask_yn "Remove config at $CONFIG_FILE?"; then
    rm "$CONFIG_FILE"
    echo "Config removed."
  else
    echo "Config kept at $CONFIG_FILE"
  fi
fi

echo "Uninstall complete."
