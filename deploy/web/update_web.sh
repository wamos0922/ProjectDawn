#!/usr/bin/env bash
# Builds the browser version from GitHub main and puts it online. Runs on the VM.
# First time: sudo bash update_web.sh --install   (then it checks every 5 minutes)
# By hand:    sudo bash /opt/dawn/update_web.sh --force
# Log:        journalctl -u dawn-web-update -n 50
set -euo pipefail
REPO=${REPO:-https://github.com/wamos0922/ProjectDawn.git}
BRANCH=${BRANCH:-main}
GODOT_VER=4.7.2
BASE=${BASE:-/opt/dawn}
SRC=$BASE/src
GODOT=${GODOT:-$BASE/godot/Godot_v${GODOT_VER}-stable_linux.x86_64}
SITE_DIR=${SITE_DIR:-/var/www/dawn}
TPL=$HOME/.local/share/godot/export_templates/${GODOT_VER}.stable

if [[ "${1:-}" == "--install" ]]; then
  apt-get install -y git unzip curl
  mkdir -p $BASE/godot
  cp "$0" $BASE/update_web.sh
  if [[ ! -x $GODOT ]]; then
    curl -fL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VER}-stable/Godot_v${GODOT_VER}-stable_linux.x86_64.zip"
    unzip -o /tmp/godot.zip -d $BASE/godot && rm /tmp/godot.zip
  fi
  if [[ ! -f $TPL/web_nothreads_release.zip ]]; then
    curl -fL -o /tmp/tpl.tpz "https://github.com/godotengine/godot/releases/download/${GODOT_VER}-stable/Godot_v${GODOT_VER}-stable_export_templates.tpz"
    mkdir -p $TPL
    unzip -j -o /tmp/tpl.tpz 'templates/version.txt' 'templates/web_nothreads_release.zip' -d $TPL && rm /tmp/tpl.tpz
  fi
  if ! swapon --show | grep -q /swapfile; then
    fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
    grep -q /swapfile /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
  cat > /etc/systemd/system/dawn-web-update.service <<UNIT
[Unit]
Description=Project Dawn: rebuild the browser version when main changes
[Service]
Type=oneshot
Environment=HOME=$HOME
ExecStart=/bin/bash $BASE/update_web.sh
UNIT
  cat > /etc/systemd/system/dawn-web-update.timer <<UNIT
[Unit]
Description=Check GitHub for Project Dawn updates every 5 minutes
[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
UNIT
  systemctl daemon-reload
  systemctl enable --now dawn-web-update.timer
  set -- --force
fi

if [[ ! -d $SRC/.git ]]; then
  git clone --depth 1 -b "$BRANCH" "$REPO" "$SRC"
  FORCE=1
fi
cd "$SRC"
OLD=$(git rev-parse HEAD)
git fetch -q --depth 1 origin "$BRANCH"
git reset -q --hard FETCH_HEAD
NEW=$(git rev-parse HEAD)
if [[ "$OLD" == "$NEW" && "${1:-}" != "--force" && -z "${FORCE:-}" ]]; then
  echo "no change ($NEW)"; exit 0
fi
echo "building $(git log -1 --format='%h %s')"

rm -rf "$BASE/out" && mkdir -p "$BASE/out"
"$GODOT" --headless --path "$SRC" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$SRC" --export-release "Web" "$BASE/out/index.html"
[[ -s "$BASE/out/index.wasm" && -s "$BASE/out/index.pck" ]] || { echo "BUILD FAILED, site not changed"; exit 1; }

mkdir -p "$SITE_DIR"
rm -rf "$SITE_DIR.new" && cp -r "$BASE/out" "$SITE_DIR.new"
rm -rf "$SITE_DIR.old" && mv "$SITE_DIR" "$SITE_DIR.old" && mv "$SITE_DIR.new" "$SITE_DIR"
echo "$NEW" > "$SITE_DIR/version.txt"

if ! cmp -s "$SRC/deploy/relay/relay.js" /opt/dawn-relay/relay.js 2>/dev/null; then
  mkdir -p /opt/dawn-relay && cp "$SRC/deploy/relay/relay.js" /opt/dawn-relay/relay.js
  systemctl restart dawn-crew-relay 2>/dev/null || true
fi
echo "LIVE: $(git log -1 --format='%h %s')"