#!/bin/sh
set -e

DATA_DIR="/app/data"
BACKUP_DIR="/tmp/backup"
REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${BACKUP_REPO_NAME}.git"
APP_PORT="${PORT:-20128}"

mkdir -p "$DATA_DIR"

# 1. RESTORE DATABASE ON BOOT
if [ -n "$GITHUB_TOKEN" ] && [ -n "$GITHUB_USER" ] && [ -n "$BACKUP_REPO_NAME" ]; then
  git clone --depth 1 "$REPO_URL" "$BACKUP_DIR" 2>/dev/null || true
  if [ -f "$BACKUP_DIR/storage.sqlite" ]; then
    cp "$BACKUP_DIR/storage.sqlite" "$DATA_DIR/storage.sqlite"
    echo "[Backup] Restored storage.sqlite from GitHub."
  fi
fi

# 2. BACKGROUND AUTO-BACKUP LOOP (EVERY 5 MINUTES)
if [ -d "$BACKUP_DIR/.git" ]; then
  (
    cd "$BACKUP_DIR" || exit 0
    git config user.email "backup@omniroute.local"
    git config user.name "OmniRoute Backup"
    while true; do
      sleep 300
      if [ -f "$DATA_DIR/storage.sqlite" ]; then
        sqlite3 "$DATA_DIR/storage.sqlite" ".backup $BACKUP_DIR/storage.sqlite"
        if [ -n "$(git status --porcelain)" ]; then
          git add storage.sqlite
          git commit -m "Auto-backup $(date -u +%Y-%m-%dT%H:%M:%SZ)"
          git push origin main --force || true
          echo "[Backup] Pushed updated storage.sqlite to GitHub."
        fi
      fi
    done
  ) &
fi

# 3. START OMNIROUTE (HEADLESS, BOUND TO HOSTLESS PORT)
exec omniroute --no-open --port "$APP_PORT"
