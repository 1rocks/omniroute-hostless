#!/bin/sh
set -u

DATA_DIR="/tmp/omniroute-data"
BACKUP_DIR="/tmp/backup"
APP_PORT="${PORT:-20128}"

export HOST="0.0.0.0"
export PORT="$APP_PORT"
export DATA_DIR="$DATA_DIR"

mkdir -p "$DATA_DIR"

echo "Starting OmniRoute wrapper on port $APP_PORT using $DATA_DIR..."

if [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_USER:-}" ] && [ -n "${BACKUP_REPO_NAME:-}" ]; then
  REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${BACKUP_REPO_NAME}.git"
  rm -rf "$BACKUP_DIR"
  if git clone --depth 1 "$REPO_URL" "$BACKUP_DIR" 2>/dev/null; then
    if [ -f "$BACKUP_DIR/storage.sqlite" ]; then
      cp "$BACKUP_DIR/storage.sqlite" "$DATA_DIR/storage.sqlite"
      echo "[Backup] Restored storage.sqlite from GitHub."
    else
      echo "[Backup] Connected to repo, no existing storage.sqlite yet."
    fi

    (
      cd "$BACKUP_DIR" || exit 0
      git config user.email "backup@omniroute.local"
      git config user.name "OmniRoute Backup"
      while true; do
        sleep 300
        if [ -f "$DATA_DIR/storage.sqlite" ]; then
          sqlite3 "$DATA_DIR/storage.sqlite" ".backup $BACKUP_DIR/storage.sqlite" 2>/dev/null || cp "$DATA_DIR/storage.sqlite" "$BACKUP_DIR/storage.sqlite"
          if [ -n "$(git status --porcelain)" ]; then
            git add storage.sqlite
            git commit -m "Auto-backup $(date -u +%Y-%m-%dT%H:%M:%SZ)" >/dev/null 2>&1 || true
            git push origin HEAD --force >/dev/null 2>&1 || true
            echo "[Backup] Pushed updated storage.sqlite."
          fi
        fi
      done
    ) &
  else
    echo "[Backup] Warning: Could not clone backup repo. Continuing without remote backup."
  fi
fi

exec omniroute --no-open --port "$APP_PORT"
