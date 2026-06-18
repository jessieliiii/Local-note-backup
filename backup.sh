#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/note-backup/config"
LOG_FILE="$HOME/.local/share/note-backup/backup.log"
LOG_MAX_LINES=1000

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "$msg" >> "$LOG_FILE"
  # Rotate log when it exceeds LOG_MAX_LINES
  local line_count
  line_count=$(wc -l < "$LOG_FILE")
  if (( line_count > LOG_MAX_LINES )); then
    tail -n "$LOG_MAX_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
}

notify_error() {
  local msg="$1"
  local hint="$2"
  osascript -e "display notification \"$msg\n$hint\" with title \"Note Backup Failed\" subtitle \"Check log: $LOG_FILE\" sound name \"Basso\"" 2>/dev/null || true
}

die() {
  log "ERROR: $*"
  # Map common errors to actionable hints
  local hint=""
  case "$*" in
    *"git clone failed"*)      hint="Check your repo URL and SSH key (ssh -T git@github.com)." ;;
    *"git pull failed"*)       hint="A rebase conflict may need manual resolution in: $GITHUB_STAGING_DIR" ;;
    *"git push failed"*)       hint="Check your SSH key or network. Try: git -C \"$GITHUB_STAGING_DIR\" push" ;;
    *"Config not found"*)      hint="Run ./setup.sh to create the config." ;;
    *"Source directory"*)      hint="Update SOURCE_DIR in $CONFIG_FILE." ;;
    *"Obsidian vault"*)        hint="Check OBSIDIAN_VAULT_DIR in $CONFIG_FILE." ;;
    *)                         hint="See full log at $LOG_FILE" ;;
  esac
  notify_error "$*" "$hint"
  exit 1
}

backup_github() {
  log "Starting GitHub backup (mode: $BACKUP_MODE)..."

  if [[ -z "$GITHUB_REPO_URL" ]]; then
    die "GITHUB_REPO_URL is not set in config."
  fi

  mkdir -p "$GITHUB_STAGING_DIR"

  # Clone if staging dir is not a git repo yet
  if [[ ! -d "$GITHUB_STAGING_DIR/.git" ]]; then
    log "Cloning $GITHUB_REPO_URL into $GITHUB_STAGING_DIR"
    git clone "$GITHUB_REPO_URL" "$GITHUB_STAGING_DIR" || die "git clone failed."
  fi

  # Pull latest before syncing (rebase to avoid merge commits)
  log "Pulling latest from remote..."
  git -C "$GITHUB_STAGING_DIR" pull --rebase --autostash || die "git pull failed."

  if [[ "$BACKUP_MODE" == "timestamp" ]]; then
    local dest="$GITHUB_STAGING_DIR/$TIMESTAMP"
    mkdir -p "$dest"
    log "Syncing files into timestamped folder: $TIMESTAMP"
    rsync -av --exclude='.DS_Store' "$SOURCE_DIR/" "$dest/"
    git -C "$GITHUB_STAGING_DIR" add -A
    git -C "$GITHUB_STAGING_DIR" commit -m "backup: $TIMESTAMP" || { log "Nothing to commit."; return; }
    git -C "$GITHUB_STAGING_DIR" push || die "git push failed."
    log "Pushed timestamped backup: $TIMESTAMP"
  else
    log "Syncing files from $SOURCE_DIR to staging..."
    rsync -av --exclude='.git' --exclude='.DS_Store' "$SOURCE_DIR/" "$GITHUB_STAGING_DIR/"
    git -C "$GITHUB_STAGING_DIR" add -A
    if git -C "$GITHUB_STAGING_DIR" diff --staged --quiet; then
      log "No changes to commit — skipping push."
    else
      git -C "$GITHUB_STAGING_DIR" commit -m "backup: $TIMESTAMP"
      git -C "$GITHUB_STAGING_DIR" push || die "git push failed."
      log "Pushed commit: $TIMESTAMP"
    fi
  fi
}

backup_obsidian() {
  log "Starting Obsidian vault backup (mode: $BACKUP_MODE)..."

  if [[ -z "$OBSIDIAN_VAULT_DIR" ]]; then
    die "OBSIDIAN_VAULT_DIR is not set in config."
  fi

  if [[ ! -d "$OBSIDIAN_VAULT_DIR" ]]; then
    die "Obsidian vault directory does not exist: $OBSIDIAN_VAULT_DIR"
  fi

  if [[ "$BACKUP_MODE" == "timestamp" ]]; then
    local dest="$OBSIDIAN_VAULT_DIR/$TIMESTAMP"
    mkdir -p "$dest"
    rsync -av --exclude='.DS_Store' "$SOURCE_DIR/" "$dest/"
    log "Obsidian timestamped backup complete: $dest"
  else
    rsync -av --exclude='.DS_Store' "$SOURCE_DIR/" "$OBSIDIAN_VAULT_DIR/"
    log "Obsidian vault sync complete."
  fi
}

main() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    die "Config not found at $CONFIG_FILE. Run ./setup.sh first."
  fi

  # shellcheck source=/dev/null
  source "$CONFIG_FILE"

  BACKUP_MODE="${BACKUP_MODE:-timestamp}"
  TIMESTAMP="$(date '+%Y-%m-%d_%H-%M')"

  if [[ -z "${SOURCE_DIR:-}" ]]; then
    die "SOURCE_DIR is not set in config."
  fi

  if [[ ! -d "$SOURCE_DIR" ]]; then
    die "Source directory does not exist: $SOURCE_DIR"
  fi

  log "======= Backup started (target: $BACKUP_TARGET) ======="

  case "$BACKUP_TARGET" in
    github)
      backup_github
      ;;
    obsidian)
      backup_obsidian
      ;;
    both)
      backup_github
      backup_obsidian
      ;;
    *)
      die "Unknown BACKUP_TARGET: $BACKUP_TARGET"
      ;;
  esac

  log "======= Backup complete ======="
}

main "$@"
