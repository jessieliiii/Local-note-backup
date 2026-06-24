# Local Note Backup

Backs up a local notes directory (primarily Markdown) to a **GitHub repository**, a **local Obsidian vault**, or both — on a scheduled cadence using macOS launchd.

Each backup can either create a timestamped snapshot folder (`2026-06-17_14-30/`) or overwrite the previous backup in place.

> **Recommendation:** If you want proper version control — the ability to diff changes, revert to any past state, and see exactly what changed between backups — use **GitHub** as your backup target. Every backup becomes a git commit, giving you a full history of your notes over time. The Obsidian vault option is best suited as a convenient local mirror for quick access, not as a version control solution.

---

## Dependencies

| Tool | Notes |
|------|-------|
| **macOS** | Scheduler uses launchd — Linux/Windows not supported |
| **bash** | Ships with macOS |
| **rsync** | Ships with macOS |
| **git** | Required for GitHub backup — install via Xcode CLT: `xcode-select --install` |
| **SSH key** | Required for passwordless `git push` — HTTPS will prompt for credentials on every scheduled run |

No third-party tools or package managers needed.

---

## Getting Started

**1. Clone this repo**
```bash
git clone git@github.com:youruser/Local-note-backup.git
cd Local-note-backup
```

**2. Run the setup wizard**
```bash
./setup.sh
```

The wizard prompts for:
- Source notes directory
- Backup target (GitHub / Obsidian vault / both)
- GitHub repo URL and/or Obsidian vault path
- Backup mode (timestamped folders or overwrite)
- Cadence (hourly / every 6h / daily / weekly)

Config is saved to `~/.config/note-backup/config`. The launchd job is installed automatically at the end.

**3. Run a backup immediately**
```bash
./backup.sh
```

**4. Check the log**
```bash
tail -f ~/.local/share/note-backup/backup.log
```

---

## Other Commands

```bash
./backup.sh --status    # show current config and scheduler state
./install.sh            # reinstall or reload the launchd job after config changes
./uninstall.sh          # stop the scheduler and optionally remove config
```

To change a setting without re-running the full wizard, edit `~/.config/note-backup/config` directly, then run `./install.sh`.

---

## Backup Modes

| Mode | Behaviour |
|------|-----------|
| `timestamp` (default) | Each run creates a new `YYYY-MM-DD_HH-MM/` subfolder in the target |
| `overwrite` | Files are synced in place, replacing the previous backup |

Timestamped mode grows storage over time. Overwrite mode keeps only the latest snapshot.

---

## Limitations & Risks

- **macOS only.** launchd is not available on Linux or Windows.
- **Machine must be awake.** launchd will not run scheduled jobs while the laptop is asleep. Calendar-interval jobs (daily/weekly) catch up on the next wake; interval-based jobs (hourly/every 6h) silently skip missed runs.
- **Full Disk Access required for scheduled runs.** macOS may block `/bin/bash` from accessing your files when launched via launchd, even if manual runs work fine. If you see `Operation not permitted` in the log, go to **System Settings → Privacy & Security → Full Disk Access** and add `/bin/bash`. Then reload the job: `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.notebackup.plist && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.notebackup.plist`.
- **GitHub target requires a pre-existing remote repo.** The tool clones it on first run but will not create it for you.
- **SSH key must be configured** for the GitHub remote. HTTPS remotes will hang waiting for credentials during unattended runs.
- **Obsidian overwrite mode is append-only.** Files deleted from your source directory are not removed from the vault. This is intentional to prevent accidental data loss, but the vault will accumulate stale files.
- **Timestamped GitHub mode grows the repo indefinitely.** Each backup adds a full copy of your notes. Prune old snapshots manually via `git` if storage becomes a concern.
- **No encryption.** Notes are stored in plaintext in the GitHub repo and/or Obsidian vault. Do not use a public GitHub repo for sensitive notes.
- **No conflict resolution.** If the GitHub remote has changes not in the local staging directory, `git pull --rebase` is used. Manual intervention is required if a rebase conflict occurs.
