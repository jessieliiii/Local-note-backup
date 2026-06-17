#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/note-backup/config"
PLIST_LABEL="com.notebackup"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
LOG_FILE="$HOME/.local/share/note-backup/backup.log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config not found at $CONFIG_FILE. Run ./setup.sh first."
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

mkdir -p "$HOME/.local/share/note-backup"
mkdir -p "$HOME/Library/LaunchAgents"

# Build the StartCalendarInterval or StartInterval block
cadence_xml() {
  case "$CADENCE" in
    hourly)
      echo "  <key>StartInterval</key>"
      echo "  <integer>3600</integer>"
      ;;
    every6h)
      echo "  <key>StartInterval</key>"
      echo "  <integer>21600</integer>"
      ;;
    daily)
      echo "  <key>StartCalendarInterval</key>"
      echo "  <dict>"
      echo "    <key>Hour</key>"
      echo "    <integer>$CADENCE_HOUR</integer>"
      echo "    <key>Minute</key>"
      echo "    <integer>0</integer>"
      echo "  </dict>"
      ;;
    weekly)
      echo "  <key>StartCalendarInterval</key>"
      echo "  <dict>"
      echo "    <key>Weekday</key>"
      echo "    <integer>0</integer>"
      echo "    <key>Hour</key>"
      echo "    <integer>$CADENCE_HOUR</integer>"
      echo "    <key>Minute</key>"
      echo "    <integer>0</integer>"
      echo "  </dict>"
      ;;
    *)
      echo "ERROR: Unknown CADENCE: $CADENCE" >&2
      exit 1
      ;;
  esac
}

# Write plist
cat > "$PLIST_PATH" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$PLIST_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$BACKUP_SCRIPT</string>
  </array>
$(cadence_xml)
  <key>StandardOutPath</key>
  <string>$LOG_FILE</string>
  <key>StandardErrorPath</key>
  <string>$LOG_FILE</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
PLIST_EOF

echo "Plist written to $PLIST_PATH"

# Validate
plutil -lint "$PLIST_PATH"

# Unload if already loaded, then load
BOOT_TARGET="gui/$(id -u)"
launchctl bootout "$BOOT_TARGET/$PLIST_LABEL" 2>/dev/null || true
launchctl bootstrap "$BOOT_TARGET" "$PLIST_PATH"

echo "Launchd job '$PLIST_LABEL' installed (cadence: $CADENCE)."
echo "Logs: $LOG_FILE"
