#!/bin/bash
# ============================================================
#  GoCBT Panel - Installer satu perintah
#
#  Penggunaan:
#    curl -fsSL https://raw.githubusercontent.com/gocbtsystem-rgb/gocbtsystem/main/install.sh | sudo bash
#
#  Bisa dijalankan ulang untuk update binary (tanpa menghapus .env).
# ============================================================
set -e

REPO="gocbtsystem-rgb/gocbtsystem"
BINARY="gocbt-panel-linux"
INSTALL_DIR="/opt/gocbt-panel"
SERVICE="gocbt-panel"

# --- wajib root ---
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: jalankan sebagai root."
  echo "  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sudo bash"
  exit 1
fi

if [ -f /etc/os-release ]; then
  . /etc/os-release
  echo "OS: ${PRETTY_NAME:-tidak dikenal}"
fi
echo "== GoCBT Panel installer =="

# --- [1/5] download binary ---
mkdir -p "$INSTALL_DIR"
echo "[1/5] Mengunduh binary..."
curl -fsSL -o "$INSTALL_DIR/gocbt-panel" "https://raw.githubusercontent.com/$REPO/main/$BINARY"
chmod +x "$INSTALL_DIR/gocbt-panel"
echo "      OK: $INSTALL_DIR/gocbt-panel"

# --- [2/5] .env (jangan timpa bila sudah ada) ---
if [ ! -f "$INSTALL_DIR/.env" ]; then
  echo "[2/5] Membuat .env dengan kredensial acak..."
  ADMIN_PASS="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)"
  SESSION_SECRET="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 48)"
  cat > "$INSTALL_DIR/.env" <<EOF
PANEL_PORT=9000
PANEL_USER=admin
PANEL_PASS=$ADMIN_PASS
SESSION_SECRET=$SESSION_SECRET
PANEL_BASE_DIR=$INSTALL_DIR
EOF
  chmod 600 "$INSTALL_DIR/.env"
  echo "      OK"
else
  echo "[2/5] .env sudah ada, dilewati (kredensial lama dipertahankan)."
fi

# --- [3/5] systemd service ---
echo "[3/5] Memasang systemd service..."
cat > "/etc/systemd/system/$SERVICE.service" <<EOF
[Unit]
Description=GoCBT Panel
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/gocbt-panel
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null 2>&1 || true
systemctl restart "$SERVICE"
echo "      OK"

# --- [4/5] tunggu service ---
echo "[4/5] Menunggu service..."
sleep 3
if ! systemctl is-active --quiet "$SERVICE"; then
  echo "ERROR: service gagal berjalan."
  echo "Cek log: journalctl -u $SERVICE -n 50 --no-pager"
  exit 1
fi

# --- [5/5] ringkasan ---
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -z "$IP" ] && IP="IP-SERVER"
PASS="$(grep '^PANEL_PASS=' "$INSTALL_DIR/.env" | cut -d= -f2)"
echo ""
echo "=============================================="
echo " GoCBT Panel terinstal & berjalan!"
echo ""
echo "  URL      : http://$IP:9000"
echo "  Username : admin"
echo "  Password : $PASS"
echo ""
echo "  Segera ganti password setelah login pertama."
echo "=============================================="
