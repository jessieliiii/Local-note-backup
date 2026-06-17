#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/note-backup"
CONFIG_FILE="$CONFIG_DIR/config"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

print_header() {
  echo ""
  echo "============================================"
  echo "  Notes Backup — First-time Setup"
  echo "============================================"
  echo ""
}

ask() {
  local prompt="$1"
  local default="${2:-}"
  local answer
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " answer
    echo "${answer:-$default}"
  else
    read -r -p "$prompt: " answer
    echo "$answer"
  fi
}

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

pick_backup_mode() {
  echo "" >&2
  echo "Backup mode:" >&2
  echo "  1) Timestamped folders (default) — each backup saved as YYYY-MM-DD_HH-MM subfolder" >&2
  echo "  2) Overwrite — sync files in place, replacing the previous backup" >&2
  echo "" >&2
  local choice
  while true; do
    read -r -p "Choose [1-2, default 1]: " choice
    choice="${choice:-1}"
    case "$choice" in
      1) echo "timestamp"; return ;;
      2) echo "overwrite"; return ;;
      *) echo "Please enter 1 or 2." >&2 ;;
    esac
  done
}

pick_cadence() {
  echo "" >&2
  echo "Backup cadence:" >&2
  echo "  1) Hourly" >&2
  echo "  2) Every 6 hours" >&2
  echo "  3) Daily (at a specific hour)" >&2
  echo "  4) Weekly (Sunday at a specific hour)" >&2
  echo "" >&2
  local choice
  while true; do
    read -r -p "Choose [1-4]: " choice
    case "$choice" in
      1) echo "hourly"; return ;;
      2) echo "every6h"; return ;;
      3) echo "daily"; return ;;
      4) echo "weekly"; return ;;
      *) echo "Please enter 1, 2, 3, or 4." >&2 ;;
    esac
  done
}

main() {
  print_header

  # Check for existing config
  if [[ -f "$CONFIG_FILE" ]]; then
    echo "Existing config found at $CONFIG_FILE."
    if ! ask_yn "Overwrite and reconfigure?"; then
      echo "Setup cancelled. Run ./backup.sh to back up now."
      exit 0
    fi
  fi

  # 1. Source directory
  echo "Step 1: Source notes directory"
  while true; do
    SOURCE_DIR=$(ask "Path to your notes directory" "$HOME/Notes")
    SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"
    if [[ -d "$SOURCE_DIR" ]]; then
      break
    fi
    echo "  Directory not found: $SOURCE_DIR"
    if ask_yn "  Create it?"; then
      mkdir -p "$SOURCE_DIR"
      break
    fi
  done

  # 2. Backup target
  echo ""
  echo "Step 2: Backup target"
  echo "  1) GitHub repository (remote)  [recommended for version control — full history, diff, revert]"
  echo "  2) Obsidian vault (local)       [convenient local mirror, no version history]"
  echo "  3) Both"
  echo ""
  local target_choice
  while true; do
    read -r -p "Choose [1-3]: " target_choice
    case "$target_choice" in
      1) BACKUP_TARGET="github"; break ;;
      2) BACKUP_TARGET="obsidian"; break ;;
      3) BACKUP_TARGET="both"; break ;;
      *) echo "Please enter 1, 2, or 3." ;;
    esac
  done

  # 3. GitHub config
  GITHUB_REPO_URL=""
  GITHUB_STAGING_DIR="$HOME/.local/share/note-backup/staging"
  if [[ "$BACKUP_TARGET" == "github" || "$BACKUP_TARGET" == "both" ]]; then
    echo ""
    echo "Step 3a: GitHub repository"
    echo "  Use SSH URL for passwordless push (e.g. git@github.com:user/notes.git)"
    while true; do
      GITHUB_REPO_URL=$(ask "GitHub repo URL")
      if [[ -n "$GITHUB_REPO_URL" ]]; then
        break
      fi
      echo "  Repo URL cannot be empty."
    done
    GITHUB_STAGING_DIR=$(ask "Local staging directory (files cloned here before push)" "$GITHUB_STAGING_DIR")
    GITHUB_STAGING_DIR="${GITHUB_STAGING_DIR/#\~/$HOME}"
  fi

  # 4. Obsidian vault config
  OBSIDIAN_VAULT_DIR=""
  if [[ "$BACKUP_TARGET" == "obsidian" || "$BACKUP_TARGET" == "both" ]]; then
    echo ""
    echo "Step 3b: Obsidian vault"
    while true; do
      OBSIDIAN_VAULT_DIR=$(ask "Path to Obsidian vault directory")
      OBSIDIAN_VAULT_DIR="${OBSIDIAN_VAULT_DIR/#\~/$HOME}"
      if [[ -d "$OBSIDIAN_VAULT_DIR" ]]; then
        break
      fi
      echo "  Directory not found: $OBSIDIAN_VAULT_DIR"
      if ask_yn "  Create it?"; then
        mkdir -p "$OBSIDIAN_VAULT_DIR"
        break
      fi
    done
  fi

  # 5. Backup mode
  echo ""
  echo "Step 4: Backup mode"
  BACKUP_MODE=$(pick_backup_mode)

  # 6. Cadence
  echo ""
  echo "Step 5: Backup cadence"
  CADENCE=$(pick_cadence)
  CADENCE_HOUR="2"
  if [[ "$CADENCE" == "daily" || "$CADENCE" == "weekly" ]]; then
    while true; do
      CADENCE_HOUR=$(ask "At which hour? (0-23, 24h format)" "2")
      if [[ "$CADENCE_HOUR" =~ ^([0-9]|1[0-9]|2[0-3])$ ]]; then
        break
      fi
      echo "  Please enter a number between 0 and 23."
    done
  fi

  # Write config
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" <<EOF
SOURCE_DIR="$SOURCE_DIR"
BACKUP_TARGET="$BACKUP_TARGET"
GITHUB_REPO_URL="$GITHUB_REPO_URL"
GITHUB_STAGING_DIR="$GITHUB_STAGING_DIR"
OBSIDIAN_VAULT_DIR="$OBSIDIAN_VAULT_DIR"
BACKUP_MODE="$BACKUP_MODE"
CADENCE="$CADENCE"
CADENCE_HOUR="$CADENCE_HOUR"
EOF
  echo ""
  echo "Config written to $CONFIG_FILE"

  # Install launchd job
  echo ""
  "$SCRIPT_DIR/install.sh"

  echo ""
  echo "All done! Run ./backup.sh to trigger a backup immediately."
}

main "$@"
